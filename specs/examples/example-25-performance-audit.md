# Spec 25: Performance Audit + Optimization

## KB files to read first
- docs/performance.md
- docs/server-add-site.md (nginx config)
- /etc/nginx/sites-enabled/migrator
- app/page.tsx (homepage sections)
- components/service-page/ServicePageTemplate.tsx

## Goal
Lighthouse Performance 90+ on all pages. Final optimization pass after all previous specs.

## Background — already done
- Server components on all pages (Spec 20) ✅
- Images compressed via sharp ✅
- AVIF/WebP enabled ✅
- WCAG contrast fixed ✅
- ScrollToTop added ✅
- Heading hierarchy fixed ✅

## Requirements

### 1. Bundle analysis (first step — diagnose before optimizing)
```bash
ANALYZE=true npx next build
# or
npx @next/bundle-analyzer
```
Check for oversized dependencies. Common fixes:
- Full lodash → lodash-es or native
- moment → date-fns or dayjs
- Large icon sets loaded fully → tree-shake

### 2. Dynamic imports for heavy below-fold components
Use `next/dynamic` for client components that are far below fold:
```typescript
import dynamic from 'next/dynamic';
const QuizWidget = dynamic(() => import('@/components/sections/QuizWidget'), {
  loading: () => <div className="h-96 animate-pulse bg-muted rounded-xl" />,
});
```

Candidates for dynamic import:
- QuizWidget — complex client component with state
- ReviewsBlock — many cards, heavy render
- ComparisonTable — large table

Note: these are client components imported into server pages. `next/dynamic` with loading fallback gives the same UX benefit as Suspense but works with the current architecture.

### 3. Brotli compression on nginx
```bash
nginx -V 2>&1 | grep brotli
```
If ngx_brotli available:
```nginx
brotli on;
brotli_static on;
brotli_comp_level 6;
brotli_types text/plain text/css text/javascript application/javascript application/json application/xml font/woff2 image/svg+xml;
```
If not available — skip. Gzip already configured.

### 4. Content-visibility on long pages
In globals.css, add utility class:
```css
.cv-auto {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}
```
Apply to sections far below fold on homepage (FAQ, Contact, etc.).

### 5. Lighthouse audit on production
After all changes deployed, run PageSpeed Insights (pagespeed.web.dev):
- Homepage — mobile + desktop
- One service page (viza-talantov or eb3) — mobile + desktop

Target: all scores 90+. Fix whatever issues Lighthouse reports:
- Render-blocking resources → defer/async
- Unused CSS/JS → purge or lazy
- CLS → fixed dimensions on all media
- LCP → priority on hero image (should already be set)
- Missing aria labels → add where flagged

## Before starting
- Commit current state: `git tag pre-spec-25`
- All specs 20-24 should be completed and deployed
- Install bundle analyzer: `npm install -D @next/bundle-analyzer`

## Tasks
1. Run bundle analyzer — identify oversized deps
2. Fix any bundle issues found
3. Add dynamic imports for heavy below-fold components
4. Add content-visibility utility class
5. Check and configure Brotli on nginx (if available)
6. Build + deploy to production
7. Run PageSpeed Insights — record all scores
8. Fix any Lighthouse issues
9. Re-run PageSpeed Insights — verify 90+ on all metrics

## Deploy after completion
```
npm run build && git push origin dev
# On server:
cd /var/www/migrator && git pull && npm install && npm run build && pm2 restart migrator
sudo nginx -t && sudo systemctl reload nginx  # only if nginx changed
```

## Boundaries
- **Always:** test on localhost before deploying, measure before and after
- **Ask first:** before modifying nginx config
- **Never:** remove existing gzip config, sacrifice functionality for score

## Done when
- Lighthouse Performance 90+ (mobile + desktop)
- Lighthouse Accessibility 90+
- Lighthouse Best Practices 90+
- Lighthouse SEO 90+
- No oversized bundles (bundle analyzer clean)
- Dynamic imports on heavy below-fold components
- npm run build passes
