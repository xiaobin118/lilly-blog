import { getCollection } from 'astro:content';

// Build-time JSON index consumed by the client-side search (CommandPalette).
export async function GET() {
  const posts = await getCollection('blog');
  const base = import.meta.env.BASE_URL;
  const index = posts.map((post) => ({
    id: post.id,
    title: post.data.title,
    description: post.data.description ?? '',
    tags: post.data.tags,
    type: post.data.type,
    topic: post.data.topic ?? '',
    date: post.data.date.toISOString(),
    url: `${base}post/${post.id}/`,
    body: (post.body ?? '').slice(0, 6000),
  }));
  return new Response(JSON.stringify(index), {
    headers: { 'Content-Type': 'application/json' },
  });
}
