import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const saveProgress = mutation({
  args: {
    mediaId: v.string(),
    title: v.string(),
    posterURL: v.optional(v.string()),
    season: v.optional(v.number()),
    episode: v.optional(v.number()),
    currentTime: v.number(),
    duration: v.number(),
    translationId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchProgress")
      .withIndex("by_mediaId", (q) => q.eq("mediaId", args.mediaId))
      .first();

    const updatedAt = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        currentTime: args.currentTime,
        duration: args.duration,
        season: args.season,
        episode: args.episode,
        translationId: args.translationId,
        updatedAt,
      });
      return existing._id;
    } else {
      return await ctx.db.insert("watchProgress", {
        mediaId: args.mediaId,
        title: args.title,
        posterURL: args.posterURL,
        season: args.season,
        episode: args.episode,
        currentTime: args.currentTime,
        duration: args.duration,
        translationId: args.translationId,
        updatedAt,
      });
    }
  },
});

export const getContinueWatching = query({
  args: {},
  handler: async (ctx) => {
    const all = await ctx.db
      .query("watchProgress")
      .withIndex("by_updatedAt")
      .order("desc")
      .take(25);

    return all.filter((item) => {
      const fraction = item.duration > 0 ? item.currentTime / item.duration : 0;
      return fraction < 0.92 && item.currentTime > 10;
    });
  },
});

export const removeProgress = mutation({
  args: {
    mediaId: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchProgress")
      .withIndex("by_mediaId", (q) => q.eq("mediaId", args.mediaId))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
    }
  },
});
