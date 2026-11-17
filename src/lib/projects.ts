// Helpers for the article -> project relation. Kept framework-free so both
// pages and the search index can use them.

export interface ProjectRef {
  id: string;
  data: { project?: string };
}

/** Number of blog entries attached to each project id (unknown ids included). */
export function countByProject(entries: ProjectRef[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const entry of entries) {
    const id = entry.data.project;
    if (!id) continue;
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  return counts;
}

/**
 * Throws when an entry points at a project that does not exist. Build-time
 * failure is deliberate: a silent miss turns into an article that looks
 * like it belongs nowhere.
 */
export function assertKnownProjects(entries: ProjectRef[], known: Set<string>): void {
  const broken = entries.filter((entry) => entry.data.project && !known.has(entry.data.project));
  if (broken.length === 0) return;

  const detail = broken.map((entry) => `  - ${entry.id}: project "${entry.data.project}"`).join('\n');
  const available = [...known].sort().join(', ') || '(none)';
  throw new Error(`Unknown project reference(s). Available projects: ${available}\n${detail}`);
}
