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
    const remoteCountRef = useRef(0);

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const clientRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const micRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const camRef = useRef<any>(null);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const remoteAudioRef = useRef<any[]>([]);
    const mutedRef = useRef(muted);
    mutedRef.current = muted;

    function updateState(next: LiveConnectionState, detail?: string) {
      setState(next);
      onStateChange?.(next, detail);
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

      async function boot() {
        updateState("connecting");
        setError(null);

        if (!isAgoraConfigured()) {
          updateState("error", "Agora App ID missing — set NEXT_PUBLIC_AGORA_APP_ID");
          return;
        }

        try {
          const tokenRes = await fetch("/api/agora/token", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ channelName, role }),
          });
          const tokenData = await tokenRes.json();
          if (!tokenRes.ok || tokenData.demoMode || !tokenData.appId) {
            updateState(
              "error",
              tokenData.error ?? "Agora is not configured for live streaming",
            );
            return;
          }

          const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
          AgoraRTC.setLogLevel(3);
          const client = AgoraRTC.createClient({
            mode: "live",
            codec: "vp8",
          });
          clientRef.current = client;

          await client.setClientRole(
            role === "publisher" ? "host" : "audience",
          );

          if (role === "publisher") {
            await client.enableDualStream?.().catch(() => undefined);
          }

          client.on(
            "user-published",
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            async (user: any, mediaType: "audio" | "video") => {
              await client.subscribe(user, mediaType);
              if (mediaType === "video") {
                const target =
                  role === "publisher" && guestRef.current
                    ? guestRef.current
                    : primaryRef.current;
                if (target) user.videoTrack?.play(target, { fit: "cover" });
                remoteCountRef.current += 1;
                setRemoteHosts(remoteCountRef.current);
                onRemoteHostsChange?.(remoteCountRef.current);
              }
              if (mediaType === "audio") {
                user.audioTrack?.play();
                user.audioTrack?.setVolume(mutedRef.current ? 0 : 100);
                remoteAudioRef.current.push(user.audioTrack);
              }
            },
          );

          client.on("user-unpublished", (_user: unknown, mediaType: string) => {
            if (mediaType === "video") {
              remoteCountRef.current = Math.max(0, remoteCountRef.current - 1);
              setRemoteHosts(remoteCountRef.current);
              onRemoteHostsChange?.(remoteCountRef.current);
            }
          });

          client.on(
            "network-quality",
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (stats: any) => {
              const up = stats?.uplinkNetworkQuality ?? 0;
              const down = stats?.downlinkNetworkQuality ?? 0;
              const score = Math.max(up, down);
              setQuality(
                score <= 2 ? "Excellent" : score <= 4 ? "Good" : "Fair",
              );
              onLatencySample?.(
                score <= 2 ? 650 : score <= 4 ? 1100 : 1700,
              );
            },
          );

          await client.join(
            tokenData.appId || AGORA_APP_ID,
            channelName,
            tokenData.token ?? null,
            tokenData.uid ?? null,
          );

          if (role === "publisher") {
            const [mic, cam] = await AgoraRTC.createMicrophoneAndCameraTracks(
              { AEC: true, ANS: true },
              {
                encoderConfig: {
                  width: 1280,
                  height: 720,
                  frameRate: 30,
                  bitrateMin: 800,
                  bitrateMax: 3000,
                },
                optimizationMode: "motion",
              },
            );
            micRef.current = mic;
            camRef.current = cam;
            if (primaryRef.current) cam.play(primaryRef.current, { fit: "cover" });
            await client.publish([mic, cam]);
          }

          if (!disposed) {
            updateState("connected", "Agora RTC connected");
            onLatencySample?.(role === "publisher" ? 700 : 900);
            statsTimer = setInterval(async () => {
              try {
                const stats = await client.getRTCStats?.();
                if (stats?.RTT) {
                  onLatencySample?.(Math.min(1900, Number(stats.RTT) + 400));
                }
              } catch {
                /* ignore */
              }
            }, 4000);
          }
        } catch (err) {
          console.error(err);
          if (!disposed) {
            const message =
              err instanceof Error ? err.message : "Stream failed";
            setError(message);
            updateState(
              "error",
              /permission|NotAllowed/i.test(message)
                ? "Camera/mic permission denied"
                : message,
            );
          }
        }
      }

      void boot();

      return () => {
        disposed = true;
        if (statsTimer) clearInterval(statsTimer);
        void (async () => {
          try {
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
    }, [channelName, role]);

    const overlay =
      state === "connecting" ||
      state === "idle" ||
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
                  : "Camera offline"}
              </p>
              <p className="mt-2 max-w-sm text-xs text-white/75">
                {state === "connecting" || state === "idle"
                  ? "Joining channel…"
                  : error || "Check Agora credentials and camera permissions."}
              </p>
            </div>
          </div>
        )}

        {state === "connected" && quality !== "—" && (
          <div className="pointer-events-none absolute bottom-3 left-3 z-[6] rounded-md bg-black/40 px-2 py-0.5 text-[9px] font-semibold text-white/70">
            {quality}
            {remoteHosts > 0 ? ` · +${remoteHosts}` : ""}
          </div>
        )}
      </div>
    );
  },
);
