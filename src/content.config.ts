import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    date: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    type: z.enum(['article', 'note', 'research']).default('article'),
    topic: z.string().optional(),
    // Id of the project this article belongs to (see the projects collection).
    project: z.string().optional(),
  }),
});

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    date: z.coerce.date(),
    status: z.enum(['done', 'doing', 'planned']).default('doing'),
    tech: z.array(z.string()).default([]),
    repo: z.string().url().optional(),
  }),
});

export const collections = { blog, projects };
