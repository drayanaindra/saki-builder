# SEO Expert Thinking

**Process:** Audit → Analyze → Prioritize → Implement → Measure

**Document findings:**
```
ISSUE: [Specific SEO problem]
IMPACT: [High/Medium/Low - estimated traffic/ranking effect]
FIX: [Recommended action]
```

## Core SEO Areas

### Technical SEO
- **Crawlability**: robots.txt, sitemap.xml, canonical tags, URL structure
- **Performance**: Core Web Vitals (LCP, FID, CLS), page speed, image optimization
- **Indexing**: meta robots, noindex/nofollow, hreflang for multi-language
- **Structured Data**: JSON-LD schema markup (Product, BreadcrumbList, FAQ, Organization)
- **Mobile**: Responsive design, mobile-first indexing, viewport config
- **Security**: HTTPS, mixed content, security headers

### On-Page SEO
- **Title Tags**: 50-60 chars, primary keyword near front, unique per page
- **Meta Descriptions**: 150-160 chars, compelling CTA, include keyword
- **Headings**: H1 (one per page), H2-H6 hierarchy, keyword-rich but natural
- **Content**: E-E-A-T (Experience, Expertise, Authority, Trust), keyword density 1-2%
- **Internal Linking**: Descriptive anchor text, logical site hierarchy, breadcrumbs
- **Images**: Alt text, descriptive filenames, WebP/AVIF format, lazy loading
- **URL Structure**: Short, descriptive, hyphens, lowercase, no parameters when possible

### E-Commerce SEO (Saketek-specific)
- **Product Pages**: Unique descriptions, price markup, availability, reviews schema
- **Category Pages**: Faceted navigation (canonical handling), pagination (rel next/prev)
- **Cross-border**: hreflang (id, ja, en), localized content, currency schema
- **User-Generated Content**: Reviews, Q&A for long-tail keywords

### Off-Page SEO
- **Backlinks**: Quality over quantity, relevance, anchor text diversity
- **Social Signals**: Open Graph tags, Twitter Cards
- **Local SEO**: Google Business Profile (if applicable)

### International SEO (Japan → Indonesia)
- **Language targeting**: hreflang tags (`id`, `ja-JP`, `en`)
- **Content localization**: Not just translation — cultural adaptation
- **Country-specific domains/subdirectories**: `/id/`, `/jp/`
- **Search engines**: Google (Indonesia), Google Japan, Yahoo Japan

## Implementation Checklist

### Next.js Specific
- `generateMetadata()` for dynamic meta tags
- `generateStaticParams()` for pre-rendering product pages
- `sitemap.ts` / `robots.ts` for automated generation
- `opengraph-image.tsx` for dynamic OG images
- Image component with `priority`, `sizes`, `placeholder`
- Route groups for layout-level metadata

### Audit Template
```
1. Technical Health
   - [ ] All pages crawlable (no orphan pages)
   - [ ] Sitemap up-to-date and submitted
   - [ ] No duplicate content / canonical issues
   - [ ] Core Web Vitals passing
   - [ ] Structured data valid (test with Rich Results Test)

2. Content Quality
   - [ ] Unique title + meta description per page
   - [ ] H1 on every page, proper heading hierarchy
   - [ ] Alt text on all images
   - [ ] No thin content pages

3. E-Commerce
   - [ ] Product schema on all product pages
   - [ ] BreadcrumbList schema
   - [ ] Price, availability, review data in schema
   - [ ] Faceted navigation handled (canonical/noindex)

4. International
   - [ ] hreflang implemented correctly
   - [ ] Language switcher present
   - [ ] Localized metadata
```

## Tools & Measurement
- **Google Search Console**: Index coverage, performance, Core Web Vitals
- **Lighthouse**: Performance, accessibility, SEO audit
- **Schema Validator**: search.google.com/test/rich-results
- **PageSpeed Insights**: Core Web Vitals field + lab data

## Anti-Patterns
| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Keyword stuffing | Natural language, semantic keywords |
| Duplicate meta across pages | Unique, descriptive per page |
| Ignoring Core Web Vitals | Performance is a ranking factor |
| Missing structured data | Always add relevant schema markup |
| Blocking CSS/JS in robots.txt | Let crawlers render pages |
| Client-side only rendering | SSR/SSG for SEO-critical pages |
