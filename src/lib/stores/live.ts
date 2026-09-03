"use client";

import { create } from "zustand";
import type { ChatMessage, LiveReaction } from "@/types";

interface LiveUiState {
  reactions: LiveReaction[];
  pipEnabled: boolean;
  muted: boolean;
  cartOpen: boolean;
  moderatorOpen: boolean;
  addReaction: (reaction: Omit<LiveReaction, "id" | "createdAt">) => void;
  pruneReactions: () => void;
  togglePip: () => void;
  setMuted: (muted: boolean) => void;
  setCartOpen: (open: boolean) => void;
  setModeratorOpen: (open: boolean) => void;
  appendChatLocal: (message: ChatMessage) => void;
  localChat: ChatMessage[];
}

export const useLiveStore = create<LiveUiState>((set) => ({
  reactions: [],
  pipEnabled: false,
  muted: false,
  cartOpen: false,
  moderatorOpen: false,
  localChat: [],
  addReaction: (reaction) =>
    set((state) => ({
      reactions: [
        ...state.reactions,
        {
          ...reaction,
          id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
          createdAt: Date.now(),
        },
      ].slice(-40),
    })),
  pruneReactions: () =>
    set((state) => ({
      reactions: state.reactions.filter((r) => Date.now() - r.createdAt < 2800),
    })),
  togglePip: () => set((state) => ({ pipEnabled: !state.pipEnabled })),
  setMuted: (muted) => set({ muted }),
  setCartOpen: (cartOpen) => set({ cartOpen }),
  setModeratorOpen: (moderatorOpen) => set({ moderatorOpen }),
  appendChatLocal: (message) =>
    set((state) => ({ localChat: [...state.localChat, message].slice(-80) })),
}));
