import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET() {
  const posts = (await getCollection('blog')).sort((a, b) => b.data.date.getTime() - a.data.date.getTime());
  const site = new URL(import.meta.env.BASE_URL, import.meta.env.SITE).href;
  return rss({
    title: "Lilly's Blog",
    description: 'C++、算法与学习笔记的个人技术博客',
    site,
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.date,
      link: new URL(`post/${post.id}/`, site).href,
      categories: post.data.tags,
    })),
  });
}
