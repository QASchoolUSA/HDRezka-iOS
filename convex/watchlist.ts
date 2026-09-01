import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const addToWatchlist = mutation({
  args: {
    mediaId: v.string(),
    title: v.string(),
    posterURL: v.optional(v.string()),
    year: v.optional(v.number()),
    contentType: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchlist")
      .withIndex("by_mediaId", (q) => q.eq("mediaId", args.mediaId))
      .first();

    if (!existing) {
      await ctx.db.insert("watchlist", {
        mediaId: args.mediaId,
        title: args.title,
        posterURL: args.posterURL,
        year: args.year,
        contentType: args.contentType,
        addedAt: Date.now(),
      });
    }
  },
});

export const removeFromWatchlist = mutation({
  args: {
    mediaId: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchlist")
      .withIndex("by_mediaId", (q) => q.eq("mediaId", args.mediaId))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
    }
  },
});

export const getWatchlist = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("watchlist")
      .withIndex("by_addedAt")
      .order("desc")
      .collect();
  },
});
