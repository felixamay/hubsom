"use client";

import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import {
  AGORA_APP_ID,
  isAgoraConfigured,
  type AgoraRole,
} from "@/lib/streaming/agora";

export type LiveConnectionState =
  | "idle"
  | "connecting"
  | "connected"
  | "waiting"
  | "reconnecting"
  | "demo"
  | "error";

export interface AgoraPlayerHandle {
  setMicEnabled: (enabled: boolean) => Promise<void>;
  setCamEnabled: (enabled: boolean) => Promise<void>;
  setMuted: (muted: boolean) => void;
  leave: () => Promise<void>;
}

type Props = {
  channelName: string;
  role?: AgoraRole;
  muted?: boolean;
  className?: string;
  onLatencySample?: (ms: number) => void;
  onStateChange?: (state: LiveConnectionState, detail?: string) => void;
  onRemoteHostsChange?: (count: number) => void;
};

/** Automatic rejoin attempts (with backoff) before showing a Retry button. */
const MAX_AUTO_RETRIES = 5;

/** Errors that retrying won't fix (config, permissions, unsupported browser). */
class FatalStreamError extends Error {}

// Registered once per page; Agora rejects registering the same extension twice.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let denoiserExtension: any = null;

/**
 * Agora AI Noise Suppression on the host mic. Billed per host minute after
 * 10k free/month. Wasm assets are copied to /public/agora-denoiser on
 * postinstall. Returns null (built-in ANS stays on) if unsupported.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function enableAiDenoiser(AgoraRTC: any, mic: any) {
  const { AIDenoiserExtension } = await import("agora-extension-ai-denoiser");
  if (!denoiserExtension) {
    denoiserExtension = new AIDenoiserExtension({ assetsPath: "/agora-denoiser" });
    AgoraRTC.registerExtensions([denoiserExtension]);
  }
  if (!denoiserExtension.checkCompatibility()) return null;

  const processor = denoiserExtension.createProcessor();
  // If the wasm fails to load or process, fall back to the raw mic.
  processor.on("pipeerror", () => {
    processor.unpipe();
    mic.unpipe();
    mic.pipe(mic.processorDestination);
  });
  mic.pipe(processor).pipe(mic.processorDestination);
  await processor.enable();
  return processor;
}

function friendlyError(message: string): string | null {
  if (/permission|NotAllowed/i.test(message)) {
    return "Camera/mic permission denied — allow access in your browser settings";
  }
  if (/NotFound|DEVICE_NOT_FOUND/i.test(message)) {
    return "No camera or microphone found";
  }
  if (/NotReadable|could not start/i.test(message)) {
    return "Camera is being used by another app — close it and retry";
  }
  return null;
}

export const AgoraPlayer = forwardRef<AgoraPlayerHandle, Props>(
  function AgoraPlayer(
    {
      channelName,
      role = "subscriber",
      muted = false,
      className,
      onLatencySample,
      onStateChange,
      onRemoteHostsChange,
    },
    ref,
  ) {
    const primaryRef = useRef<HTMLDivElement>(null);
    const guestRef = useRef<HTMLDivElement>(null);
    const [state, setState] = useState<LiveConnectionState>("idle");
    const [error, setError] = useState<string | null>(null);
    const [remoteHosts, setRemoteHosts] = useState(0);
    const [quality, setQuality] = useState("—");
    const [weakNetwork, setWeakNetwork] = useState(false);
    const [needsTap, setNeedsTap] = useState(false);
    // Bumping this re-runs the connect effect (manual or automatic rejoin).
    const [attempt, setAttempt] = useState(0);
    const retriesRef = useRef(0);
    const remoteVideoUidsRef = useRef(new Set<string | number>());

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const clientRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const micRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const camRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const remoteAudioRef = useRef<any[]>([]);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const denoiserRef = useRef<any>(null);
    const mutedRef = useRef(muted);
    mutedRef.current = muted;

    function updateState(next: LiveConnectionState, detail?: string) {
      setState(next);
      onStateChange?.(next, detail);
    }

    function retryNow() {
      retriesRef.current = 0;
      setAttempt((a) => a + 1);
    }

    useImperativeHandle(ref, () => ({
      setMicEnabled: async (enabled) => {
        if (micRef.current) await micRef.current.setEnabled(enabled);
      },
      setCamEnabled: async (enabled) => {
        if (camRef.current) await camRef.current.setEnabled(enabled);
      },
      setMuted: (nextMuted) => {
        for (const track of remoteAudioRef.current) {
          track?.setVolume?.(nextMuted ? 0 : 100);
        }
      },
      leave: async () => {
        try {
          micRef.current?.close?.();
          camRef.current?.close?.();
          await clientRef.current?.leave?.();
        } catch {
          /* ignore */
        }
      },
    }));

    useEffect(() => {
      for (const track of remoteAudioRef.current) {
        track?.setVolume?.(muted ? 0 : 100);
      }
    }, [muted]);

    useEffect(() => {
      let disposed = false;
      let statsTimer: ReturnType<typeof setInterval> | null = null;
      let retryTimer: ReturnType<typeof setTimeout> | null = null;
      let wakeLock: WakeLockSentinel | null = null;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let AgoraRTC: any = null;

      function syncRemoteHosts() {
        const count = remoteVideoUidsRef.current.size;
        setRemoteHosts(count);
        onRemoteHostsChange?.(count);
      }

      /** Viewers with no host video yet see "waiting" instead of a black screen. */
      function settledState(): LiveConnectionState {
        return role === "subscriber" && remoteVideoUidsRef.current.size === 0
          ? "waiting"
          : "connected";
      }

      function scheduleRetry(reason: string) {
        if (disposed || retryTimer) return;
        if (retriesRef.current >= MAX_AUTO_RETRIES) {
          setError(reason);
          updateState("error", reason);
          return;
        }
        const delay = Math.min(15_000, 1000 * 2 ** retriesRef.current);
        retriesRef.current += 1;
        updateState("reconnecting", reason);
        retryTimer = setTimeout(() => setAttempt((a) => a + 1), delay);
      }

      async function fetchToken(uid?: number) {
        const res = await fetch("/api/agora/token", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ channelName, role, uid }),
        });
        const data = await res.json();
        if (!res.ok || data.demoMode || !data.appId) {
          throw new FatalStreamError(
            data.error ?? "Agora is not configured for live streaming",
          );
        }
        return data;
      }

      // Keep the host's phone screen from sleeping mid-show.
      async function acquireWakeLock() {
        if (role !== "publisher" || !("wakeLock" in navigator)) return;
        try {
          wakeLock = await navigator.wakeLock.request("screen");
        } catch {
          /* not allowed (e.g. low battery) */
        }
      }

      function onVisibilityChange() {
        if (document.visibilityState === "visible") void acquireWakeLock();
      }

      // Leave immediately on tab close so viewers aren't left on a frozen frame.
      function onPageHide() {
        void clientRef.current?.leave?.();
      }

      async function boot() {
        updateState(attempt === 0 ? "connecting" : "reconnecting");
        setError(null);

        if (!isAgoraConfigured()) {
          updateState("error", "Agora App ID missing — set NEXT_PUBLIC_AGORA_APP_ID");
          return;
        }

        try {
          AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
          if (!AgoraRTC.checkSystemRequirements()) {
            throw new FatalStreamError(
              "This browser can't play live video — try the latest Chrome or Safari",
            );
          }
          AgoraRTC.setLogLevel(3);
          // Browsers block sound until the user taps; show a tap prompt.
          AgoraRTC.onAutoplayFailed = () => setNeedsTap(true);

          const tokenData = await fetchToken();
          const uid: number = tokenData.uid;
          if (disposed) return;

          const client = AgoraRTC.createClient({
            mode: "live",
            codec: "vp8",
          });
          clientRef.current = client;
          remoteVideoUidsRef.current.clear();
          remoteAudioRef.current = [];
          syncRemoteHosts();

          if (role === "publisher") {
            await client.setClientRole("host");
          } else {
            // Level 2 = ultra-low latency (~400–800ms) instead of the
            // multi-second CDN-style delay of level 1.
            await client.setClientRole("audience", { level: 2 });
          }

          // Start camera/mic while we join so the host goes live faster.
          // Portrait devices get a portrait encode so the full-bleed
          // "cover" layout doesn't crop away most of the pixels.
          const portrait = window.innerHeight >= window.innerWidth;
          const tracksPromise =
            role === "publisher"
              ? AgoraRTC.createMicrophoneAndCameraTracks(
                  { AEC: true, ANS: true, AGC: true },
                  {
                    encoderConfig: {
                      width: portrait ? 720 : 1280,
                      height: portrait ? 1280 : 720,
                      frameRate: 30,
                      // No bitrateMin: forcing a floor on weak uplinks causes
                      // congestion, which shows up as lag and freezes.
                      bitrateMax: 2000,
                    },
                    // Keep products sharp; drop frames rather than resolution.
                    optimizationMode: "detail",
                  },
                )
              : null;
          // Keep refs current as soon as tracks exist so cleanup can close
          // the camera even if joining fails; errors surface when awaited.
          tracksPromise
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            ?.then(([mic, cam]: any[]) => {
              if (disposed) {
                mic.close();
                cam.close();
                return;
              }
              micRef.current = mic;
              camRef.current = cam;
            })
            .catch(() => undefined);

          if (role === "publisher") {
            // The SDK's default low stream is 160×120, which looks terrible
            // if a viewer falls back to it.
            client.setLowStreamParameter?.({
              width: portrait ? 360 : 640,
              height: portrait ? 640 : 360,
              framerate: 15,
              bitrate: 500,
            });
            await client.enableDualStream?.().catch(() => undefined);
          }

          client.on(
            "user-published",
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            async (user: any, mediaType: "audio" | "video") => {
              await client.subscribe(user, mediaType);
              if (mediaType === "video") {
                // Watch the full-quality stream; only drop to the low
                // stream when the viewer's network can't keep up.
                await client
                  .setRemoteVideoStreamType?.(user.uid, 0)
                  .catch(() => undefined);
                client.setStreamFallbackOption?.(user.uid, 1);
                const target =
                  role === "publisher" && guestRef.current
                    ? guestRef.current
                    : primaryRef.current;
                if (target) user.videoTrack?.play(target, { fit: "cover" });
                remoteVideoUidsRef.current.add(user.uid);
                syncRemoteHosts();
                if (!disposed) updateState("connected");
              }
              if (mediaType === "audio") {
                user.audioTrack?.play();
                user.audioTrack?.setVolume(mutedRef.current ? 0 : 100);
                remoteAudioRef.current.push(user.audioTrack);
              }
            },
          );

          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          function dropRemote(user: any) {
            remoteVideoUidsRef.current.delete(user.uid);
            syncRemoteHosts();
            if (!disposed && client.connectionState === "CONNECTED") {
              updateState(settledState());
            }
          }

          client.on(
            "user-unpublished",
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (user: any, mediaType: string) => {
              if (mediaType === "video") dropRemote(user);
            },
          );
          client.on("user-left", dropRemote);

          // The SDK auto-reconnects short drops; we surface that, and rejoin
          // ourselves if it gives up.
          client.on(
            "connection-state-change",
            (current: string, _previous: string, reason?: string) => {
              if (disposed) return;
              if (current === "RECONNECTING") {
                updateState("reconnecting", "Connection dropped — reconnecting…");
              } else if (current === "CONNECTED") {
                updateState(settledState());
              } else if (current === "DISCONNECTED" && reason !== "LEAVE") {
                if (reason && /BANNED/.test(reason)) {
                  setError("You were removed from this live");
                  updateState("error", "You were removed from this live");
                } else {
                  scheduleRetry("Disconnected — rejoining…");
                }
              }
            },
          );

          // Tokens expire (1h by default); renew so long shows don't drop.
          client.on("token-privilege-will-expire", async () => {
            try {
              const next = await fetchToken(uid);
              if (next.token) await client.renewToken(next.token);
            } catch {
              /* the did-expire handler below rejoins */
            }
          });
          client.on("token-privilege-did-expire", () =>
            scheduleRetry("Session expired — rejoining…"),
          );

          client.on(
            "network-quality",
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (stats: any) => {
              // 0 unknown, 1–2 good, 3 poor, 4–6 bad/down
              const score =
                role === "publisher"
                  ? stats?.uplinkNetworkQuality ?? 0
                  : stats?.downlinkNetworkQuality ?? 0;
              setQuality(
                score === 0 ? "—" : score <= 2 ? "Good" : score === 3 ? "Fair" : "Weak",
              );
              setWeakNetwork(score >= 4);
            },
          );

          await client.join(
            tokenData.appId || AGORA_APP_ID,
            channelName,
            tokenData.token ?? null,
            uid ?? null,
          );

          if (tracksPromise) {
            const [mic, cam] = await tracksPromise;
            micRef.current = mic;
            camRef.current = cam;
            // Camera/mic can be killed by the OS (e.g. app backgrounded on iOS).
            cam.on("track-ended", () => scheduleRetry("Camera stopped — restarting…"));
            mic.on("track-ended", () => scheduleRetry("Microphone stopped — restarting…"));
            if (primaryRef.current) cam.play(primaryRef.current, { fit: "cover" });
            await client.publish([mic, cam]);

            // Don't hold up going live on the ~3MB wasm download.
            void enableAiDenoiser(AgoraRTC, mic)
              .then((processor) => {
                if (disposed) void processor?.destroy();
                else denoiserRef.current = processor;
              })
              .catch((err) => console.warn("AI noise suppression unavailable", err));

            // Unplugged/disabled device: switch to another instead of dying.
            AgoraRTC.onCameraChanged = async (info: {
              state: string;
              device: { label: string };
            }) => {
              const current = camRef.current;
              if (!current || info.state !== "INACTIVE") return;
              if (current.getTrackLabel?.() !== info.device.label) return;
              const [next] = await AgoraRTC.getCameras().catch(() => []);
              if (next) await current.setDevice(next.deviceId).catch(() => undefined);
            };
            AgoraRTC.onMicrophoneChanged = async (info: {
              state: string;
              device: { label: string };
            }) => {
              const current = micRef.current;
              if (!current || info.state !== "INACTIVE") return;
              if (current.getTrackLabel?.() !== info.device.label) return;
              const [next] = await AgoraRTC.getMicrophones().catch(() => []);
              if (next) await current.setDevice(next.deviceId).catch(() => undefined);
            };

            void acquireWakeLock();
          }

          if (!disposed) {
            retriesRef.current = 0;
            updateState(settledState(), "Agora RTC connected");
            statsTimer = setInterval(() => {
              try {
                if (role === "subscriber") {
                  // Real camera-to-screen delay reported by the SDK.
                  const remote = client.getRemoteVideoStats?.() ?? {};
                  const delays = Object.values(remote)
                    // eslint-disable-next-line @typescript-eslint/no-explicit-any
                    .map((s: any) => Number(s?.end2EndDelay))
                    .filter((ms) => Number.isFinite(ms) && ms > 0);
                  if (delays.length) onLatencySample?.(Math.round(Math.max(...delays)));
                } else {
                  const stats = client.getRTCStats?.();
                  if (stats?.RTT) onLatencySample?.(Math.round(Number(stats.RTT)));
                }
              } catch {
                /* ignore */
              }
            }, 2000);
          }
        } catch (err) {
          console.error(err);
          if (disposed) return;
          const message = err instanceof Error ? err.message : "Stream failed";
          const friendly = friendlyError(message);
          if (err instanceof FatalStreamError || friendly) {
            setError(friendly ?? message);
            updateState("error", friendly ?? message);
          } else {
            scheduleRetry(message);
          }
        }
      }

      document.addEventListener("visibilitychange", onVisibilityChange);
      window.addEventListener("pagehide", onPageHide);
      void boot();

      return () => {
        disposed = true;
        if (statsTimer) clearInterval(statsTimer);
        if (retryTimer) clearTimeout(retryTimer);
        document.removeEventListener("visibilitychange", onVisibilityChange);
        window.removeEventListener("pagehide", onPageHide);
        void wakeLock?.release().catch(() => undefined);
        if (AgoraRTC) {
          AgoraRTC.onAutoplayFailed = undefined;
          AgoraRTC.onCameraChanged = undefined;
          AgoraRTC.onMicrophoneChanged = undefined;
        }
        void (async () => {
          try {
            const denoiser = denoiserRef.current;
            denoiserRef.current = null;
            if (denoiser) {
              denoiser.unpipe();
              await denoiser.destroy().catch(() => undefined);
            }
            micRef.current?.close?.();
            camRef.current?.close?.();
            micRef.current = null;
            camRef.current = null;
            await clientRef.current?.leave?.();
            clientRef.current = null;
          } catch {
            /* ignore */
          }
        })();
      };
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [channelName, role, attempt]);

    const overlay =
      state === "connecting" ||
      state === "idle" ||
      state === "waiting" ||
      state === "error" ||
      state === "demo";

    return (
      <div className={`relative overflow-hidden bg-hubsom-night ${className ?? ""}`}>
        <div ref={primaryRef} className="absolute inset-0" />
        {role === "publisher" && (
          <div
            ref={guestRef}
            className="absolute bottom-[22%] left-3 z-[5] h-24 w-16 overflow-hidden rounded-lg border border-white/25 bg-black/40 sm:h-28 sm:w-20"
          />
        )}

        {overlay && (
          <div className="absolute inset-0 z-[1]">
            <div className="absolute inset-0 bg-hubsom-night" />
            <div className="absolute inset-x-0 bottom-28 flex flex-col items-center px-6 text-center text-white">
              <p className="rounded-full border border-white/20 bg-black/40 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.2em]">
                {state === "connecting" || state === "idle"
                  ? "Connecting…"
                  : state === "waiting"
                    ? "Host will be right back"
                    : "Camera offline"}
              </p>
              <p className="mt-2 max-w-sm text-xs text-white/75">
                {state === "connecting" || state === "idle"
                  ? "Joining channel…"
                  : state === "waiting"
                    ? "Stay here — the video starts automatically."
                    : error || "Check Agora credentials and camera permissions."}
              </p>
              {state === "error" && (
                <button
                  type="button"
                  onClick={retryNow}
                  className="pointer-events-auto mt-3 rounded-xl bg-hubsom-gold px-4 py-2 text-xs font-bold text-hubsom-ink"
                >
                  Try again
                </button>
              )}
            </div>
          </div>
        )}

        {/* Keep the last frame visible while reconnecting; just flag it. */}
        {state === "reconnecting" && (
          <div className="pointer-events-none absolute inset-x-0 top-1/2 z-[6] flex justify-center">
            <p className="rounded-full bg-black/60 px-3 py-1.5 text-xs font-semibold text-white backdrop-blur">
              Reconnecting…
            </p>
          </div>
        )}

        {needsTap && (
          <button
            type="button"
            onClick={() => setNeedsTap(false)}
            className="absolute inset-x-0 top-1/3 z-[7] mx-auto w-fit rounded-full bg-black/70 px-4 py-2 text-sm font-bold text-white backdrop-blur"
          >
            Tap to turn on sound
          </button>
        )}

        {state === "connected" && quality !== "—" && (
          <div
            className={`pointer-events-none absolute bottom-3 left-3 z-[6] rounded-md px-2 py-0.5 text-[9px] font-semibold ${
              weakNetwork ? "bg-hubsom-live/80 text-white" : "bg-black/40 text-white/70"
            }`}
          >
            {weakNetwork
              ? role === "publisher"
                ? "Weak connection — move closer to Wi-Fi"
                : "Weak connection"
              : quality}
            {remoteHosts > 0 ? ` · +${remoteHosts}` : ""}
          </div>
        )}
      </div>
    );
  },
);
