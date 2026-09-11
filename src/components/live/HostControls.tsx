"use client";

import {
  Mic,
  MicOff,
  MonitorUp,
  Radio,
  Users,
  Video,
  VideoOff,
} from "lucide-react";

export function HostControls({
  publishing,
  micOn,
  camOn,
  onToggleMic,
  onToggleCam,
  onInviteGuest,
  onStartRecording,
}: {
  publishing: boolean;
  micOn: boolean;
  camOn: boolean;
  onToggleMic: () => void;
  onToggleCam: () => void;
  onInviteGuest: () => void;
  onStartRecording: () => void;
}) {
  return (
    <div className="rounded-2xl border border-white/15 bg-black/45 p-3 text-white backdrop-blur">
      <div className="mb-2 flex items-center gap-2 text-xs font-bold uppercase tracking-[0.16em] text-hubsom-gold">
        <Radio className="h-3.5 w-3.5" />
        Host controls
      </div>
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={onToggleMic}
          className="inline-flex items-center gap-1 rounded-lg bg-white/10 px-3 py-2 text-xs font-semibold"
        >
          {micOn ? <Mic className="h-3.5 w-3.5" /> : <MicOff className="h-3.5 w-3.5" />}
          Mic
        </button>
        <button
          type="button"
          onClick={onToggleCam}
          className="inline-flex items-center gap-1 rounded-lg bg-white/10 px-3 py-2 text-xs font-semibold"
        >
          {camOn ? <Video className="h-3.5 w-3.5" /> : <VideoOff className="h-3.5 w-3.5" />}
          Cam
        </button>
        <button
          type="button"
          onClick={onInviteGuest}
          className="inline-flex items-center gap-1 rounded-lg bg-white/10 px-3 py-2 text-xs font-semibold"
        >
          <Users className="h-3.5 w-3.5" />
          Guest seller
        </button>
        <button
          type="button"
          onClick={onStartRecording}
          className="inline-flex items-center gap-1 rounded-lg bg-hubsom-leaf px-3 py-2 text-xs font-semibold"
        >
          <MonitorUp className="h-3.5 w-3.5" />
          {publishing ? "Recording…" : "Record / Replay"}
        </button>
      </div>
    </div>
  );
}
