declare module 'astro:content' {
	interface Render {
		'.md': Promise<{
			Content: import('astro').MarkdownInstance<{}>['Content'];
			headings: import('astro').MarkdownHeading[];
			remarkPluginFrontmatter: Record<string, any>;
		}>;
	}
}

declare module 'astro:content' {
	type Flatten<T> = T extends { [K: string]: infer U } ? U : never;

	export type CollectionKey = keyof AnyEntryMap;
	export type CollectionEntry<C extends CollectionKey> = Flatten<AnyEntryMap[C]>;

	export type ContentCollectionKey = keyof ContentEntryMap;
	export type DataCollectionKey = keyof DataEntryMap;

	type AllValuesOf<T> = T extends any ? T[keyof T] : never;
	type ValidContentEntrySlug<C extends keyof ContentEntryMap> = AllValuesOf<
		ContentEntryMap[C]
	>['slug'];

	export function getEntryBySlug<
		C extends keyof ContentEntryMap,
		E extends ValidContentEntrySlug<C> | (string & {}),
	>(
		collection: C,
		// Note that this has to accept a regular string too, for SSR
		entrySlug: E
	): E extends ValidContentEntrySlug<C>
		? Promise<CollectionEntry<C>>
		: Promise<CollectionEntry<C> | undefined>;

	export function getDataEntryById<C extends keyof DataEntryMap, E extends keyof DataEntryMap[C]>(
		collection: C,
		entryId: E
	): Promise<CollectionEntry<C>>;

	export function getCollection<C extends keyof AnyEntryMap, E extends CollectionEntry<C>>(
		collection: C,
		filter?: (entry: CollectionEntry<C>) => entry is E
	): Promise<E[]>;
	export function getCollection<C extends keyof AnyEntryMap>(
		collection: C,
		filter?: (entry: CollectionEntry<C>) => unknown
	): Promise<CollectionEntry<C>[]>;

	export function getEntry<
		C extends keyof ContentEntryMap,
		E extends ValidContentEntrySlug<C> | (string & {}),
	>(entry: {
		collection: C;
		slug: E;
	}): E extends ValidContentEntrySlug<C>
		? Promise<CollectionEntry<C>>
		: Promise<CollectionEntry<C> | undefined>;
	export function getEntry<
		C extends keyof DataEntryMap,
		E extends keyof DataEntryMap[C] | (string & {}),
	>(entry: {
		collection: C;
		id: E;
	}): E extends keyof DataEntryMap[C]
		? Promise<DataEntryMap[C][E]>
		: Promise<CollectionEntry<C> | undefined>;
	export function getEntry<
		C extends keyof ContentEntryMap,
		E extends ValidContentEntrySlug<C> | (string & {}),
	>(
		collection: C,
		slug: E
	): E extends ValidContentEntrySlug<C>
		? Promise<CollectionEntry<C>>
		: Promise<CollectionEntry<C> | undefined>;
	export function getEntry<
		C extends keyof DataEntryMap,
		E extends keyof DataEntryMap[C] | (string & {}),
	>(
		collection: C,
		id: E
	): E extends keyof DataEntryMap[C]
		? Promise<DataEntryMap[C][E]>
		: Promise<CollectionEntry<C> | undefined>;

	/** Resolve an array of entry references from the same collection */
	export function getEntries<C extends keyof ContentEntryMap>(
		entries: {
			collection: C;
			slug: ValidContentEntrySlug<C>;
		}[]
	): Promise<CollectionEntry<C>[]>;
	export function getEntries<C extends keyof DataEntryMap>(
		entries: {
			collection: C;
			id: keyof DataEntryMap[C];
		}[]
	): Promise<CollectionEntry<C>[]>;

	export function reference<C extends keyof AnyEntryMap>(
		collection: C
	): import('astro/zod').ZodEffects<
		import('astro/zod').ZodString,
		C extends keyof ContentEntryMap
			? {
					collection: C;
					slug: ValidContentEntrySlug<C>;
				}
			: {
					collection: C;
					id: keyof DataEntryMap[C];
				}
	>;
	// Allow generic `string` to avoid excessive type errors in the config
	// if `dev` is not running to update as you edit.
	// Invalid collection names will be caught at build time.
	export function reference<C extends string>(
		collection: C
	): import('astro/zod').ZodEffects<import('astro/zod').ZodString, never>;

	type ReturnTypeOrOriginal<T> = T extends (...args: any[]) => infer R ? R : T;
	type InferEntrySchema<C extends keyof AnyEntryMap> = import('astro/zod').infer<
		ReturnTypeOrOriginal<Required<ContentConfig['collections'][C]>['schema']>
	>;

	type ContentEntryMap = {
		"houses": {
"house1.md": {
	id: "house1.md";
  slug: "house1";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house10.md": {
	id: "house10.md";
  slug: "house10";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house11.md": {
	id: "house11.md";
  slug: "house11";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house12.md": {
	id: "house12.md";
  slug: "house12";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house13.md": {
	id: "house13.md";
  slug: "house13";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house14.md": {
	id: "house14.md";
  slug: "house14";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house15.md": {
	id: "house15.md";
  slug: "house15";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house2.md": {
	id: "house2.md";
  slug: "house2";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house3.md": {
	id: "house3.md";
  slug: "house3";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house4.md": {
	id: "house4.md";
  slug: "house4";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house5.md": {
	id: "house5.md";
  slug: "house5";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house6.md": {
	id: "house6.md";
  slug: "house6";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house7.md": {
	id: "house7.md";
  slug: "house7";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house8.md": {
	id: "house8.md";
  slug: "house8";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"house9.md": {
	id: "house9.md";
  slug: "house9";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"local1.md": {
	id: "local1.md";
  slug: "local1";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"local2.md": {
	id: "local2.md";
  slug: "local2";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"local3.md": {
	id: "local3.md";
  slug: "local3";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"local4.md": {
	id: "local4.md";
  slug: "local4";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
"local5.md": {
	id: "local5.md";
  slug: "local5";
  body: string;
  collection: "houses";
  data: any
} & { render(): Render[".md"] };
};
"lotes": {
"lote1.md": {
	id: "lote1.md";
  slug: "lote1";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote2.md": {
	id: "lote2.md";
  slug: "lote2";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote3.md": {
	id: "lote3.md";
  slug: "lote3";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote4.md": {
	id: "lote4.md";
  slug: "lote4";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote5.md": {
	id: "lote5.md";
  slug: "lote5";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote6.md": {
	id: "lote6.md";
  slug: "lote6";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote7.md": {
	id: "lote7.md";
  slug: "lote7";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote8.md": {
	id: "lote8.md";
  slug: "lote8";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
"lote9.md": {
	id: "lote9.md";
  slug: "lote9";
  body: string;
  collection: "lotes";
  data: any
} & { render(): Render[".md"] };
};

	};

	type DataEntryMap = {
		
	};

	type AnyEntryMap = ContentEntryMap & DataEntryMap;

	export type ContentConfig = never;
}
