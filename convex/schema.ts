import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Playback Progress & Continue Watching
  watchProgress: defineTable({
    mediaId: v.string(),
    title: v.string(),
    posterURL: v.optional(v.string()),
    season: v.optional(v.number()),
    episode: v.optional(v.number()),
    currentTime: v.number(),
    duration: v.number(),
    translationId: v.optional(v.string()),
    updatedAt: v.number(),
  })
    .index("by_mediaId", ["mediaId"])
    .index("by_updatedAt", ["updatedAt"]),

  // Watchlist / Bookmarks
  watchlist: defineTable({
    mediaId: v.string(),
    title: v.string(),
    posterURL: v.optional(v.string()),
    year: v.optional(v.number()),
    contentType: v.string(),
    addedAt: v.number(),
  })
    .index("by_mediaId", ["mediaId"])
    .index("by_addedAt", ["addedAt"]),

  // User Settings & Sync
  userPreferences: defineTable({
    userId: v.string(),
    defaultQuality: v.string(),
    preferredTranslator: v.optional(v.string()),
    subtitleScale: v.number(),
    mirrorUrl: v.optional(v.string()),
  }).index("by_userId", ["userId"]),
});
