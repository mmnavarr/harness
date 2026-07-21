-- Top 5 Most Downvoted Forum Posts
-- Description: Retrieves the forum posts with the lowest scores, including vote counts and page views
-- Usage: psql "$DATABASE_URL" -f packages/database/devdb/scripts/top-downvoted-posts.sql

SELECT
    p.id,
    p.title,
    p.score,
    p."pageViews",
    p."createdAt",
    u.name as author,
    (SELECT COUNT(*) FROM "PostVote" pv WHERE pv."postId" = p.id AND pv."voteType" = 'DOWNVOTE') as downvotes,
    (SELECT COUNT(*) FROM "PostVote" pv WHERE pv."postId" = p.id AND pv."voteType" = 'UPVOTE') as upvotes
FROM "Post" p
JOIN "User" u ON p."userId" = u.id
WHERE p."deletedAt" IS NULL
ORDER BY p.score ASC
LIMIT 5;
