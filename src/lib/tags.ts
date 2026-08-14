// Turn a tag into a URL-safe slug used for /tags/<slug>/ routes.
// Keeps alphanumerics and `+` (e.g. "c++"), collapses everything else to `-`.
export function slugifyTag(tag: string): string {
  return tag.toLowerCase().replace(/[^a-z0-9+]+/g, '-').replace(/^-+|-+$/g, '');
}
