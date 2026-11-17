const base = import.meta.env.BASE_URL;

/** URL of a blog entry (article or note). */
export const postUrl = (id: string) => `${base}post/${id}/`;

/** URL of a project page. */
export const projectUrl = (id: string) => `${base}projects/${id}/`;
