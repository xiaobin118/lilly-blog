import { getCollection } from 'astro:content';
import { postUrl, projectUrl } from '../lib/urls';

// Build-time JSON index consumed by the client-side search (CommandPalette).
export async function GET() {
  const posts = await getCollection('blog');
  const projects = await getCollection('projects');

  const index = [
    ...posts.map((post) => ({
      id: post.id,
      title: post.data.title,
      description: post.data.description ?? '',
      tags: post.data.tags,
      type: post.data.type,
      topic: post.data.topic ?? '',
      date: post.data.date.toISOString(),
      url: postUrl(post.id),
      body: (post.body ?? '').slice(0, 6000),
    })),
    ...projects.map((project) => ({
      id: project.id,
      title: project.data.title,
      description: project.data.description,
      tags: project.data.tech,
      type: 'project',
      topic: '',
      date: project.data.date.toISOString(),
      url: projectUrl(project.id),
      body: (project.body ?? '').slice(0, 6000),
    })),
  ];

  return new Response(JSON.stringify(index), {
    headers: { 'Content-Type': 'application/json' },
  });
}
