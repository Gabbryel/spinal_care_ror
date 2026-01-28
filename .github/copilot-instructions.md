# Spinal Care RoR - AI Coding Agent Instructions

## Project Overview

Romanian medical clinic website built with Rails 7, Hotwire (Turbo + Stimulus), esbuild, and Tailwind CSS. Primary language: Romanian. Handles medical staff, services, specialties, and patient information.

## Critical Guidelines

⚠️ **When in doubt, ASK!** Do not invent implementations or guess at requirements. Always confirm with the user if unsure.

- If a task is unclear or ambiguous, request clarification before proceeding
- When unsure about existing patterns or conventions, confirm with the user
- Never fabricate functionality, API endpoints, or database schemas - verify first
- If multiple implementation approaches exist, present options and ask for preference

## Architecture & Key Patterns

### URL & Routing Convention

- **Romanian URLs**: All public routes use Romanian paths (`/echipa`, `/servicii-medicale`, `/specialitati-medicale`)
- **Slug-based routing**: Models use parameterized slugs via `to_param` for SEO-friendly URLs
- **Slug generation**: Automatic via `SlugHelper` concern - uses `name` (or `first_name-last_name` for members), falls back to `name-id` if duplicate
- **Error handling**: `rescue_from RecordNotFound` searches for similar slugs before redirecting (see [members_controller.rb](app/controllers/members_controller.rb))

### Authentication & Authorization

- **Devise** for authentication (skip for most public actions)
- **Pundit** for authorization - all controllers verify policies except Devise, admin, and pages
- **User roles**: `admin` and `god_mode` boolean flags (helpers in [application_helper.rb](app/helpers/application_helper.rb))
- **Admin access**: Layout switches to `dashboard` layout for admin actions

### Models & Data Patterns

- **Rich text fields**: Use Action Text's `has_rich_text :description` for `Member`, `MedicalService`, `Specialty`, `Fact`
- **Image storage**: Cloudinary in production via Active Storage, local disk in development
- **Associations**:
  - `Member` → `belongs_to :profession`, `belongs_to :specialty` (optional), `has_many :medical_services`
  - `MedicalService` → `belongs_to :specialty`, `has_many :members`
- **Slug concerns**: Include `SlugHelper` and `CheckSlugHelper` in models needing SEO URLs

### Views & Frontend

#### Stimulus Controllers Pattern

Active controllers in [app/javascript/controllers](app/javascript/controllers):

- `animation_controller.js` - scroll-triggered animations via `data-action="scroll@window->animation#svgscroll"`
- `masonry_controller.js` - grid layouts for medical services/professions
- `memberIndexFilter_controller.js` - filter medical team by profession/specialty
- `navbarFixed_controller.js` - sticky navbar on scroll
- `tooltip_controller.js` - custom tooltips for admin/service cards
- `bio_controller.js` - expand/collapse member biographies
- `reviews_controller.js` - homepage review carousel

#### Helper Patterns

- **Cloudinary helpers**: Use `cl_image_tag(image, quality: 60, width: 1000, crop: "scale")` for optimized images
- **Background photos**: `BkgPhotosHelper#bkg_photo` returns random Cloudinary image path
- **Meta tags**: Centralized in [config/meta.yml](config/meta.yml), accessed via `DEFAULT_META` constant ([default_meta.rb](config/initializers/default_meta.rb))
- **Render helpers**: See [render_photo_text_sections_helper.rb](app/helpers/render_photo_text_sections_helper.rb) for feature section rendering

### Development Workflow

#### Start Development Server

```bash
bin/dev  # Runs foreman with Procfile.dev
```

Procfile processes:

- `rails server -p 3000`
- `yarn build --watch` - esbuild with live reload
- `tailwindcss:watch` - Tailwind compilation

#### Build Configuration

- **JavaScript**: [esbuild.config.mjs](esbuild.config.mjs) - bundles from `app/javascript`, outputs to `app/assets/builds`
- **Live reload**: esbuild watch mode injects EventSource for browser refresh on file changes
- **CSS**: Tailwind via `tailwindcss-rails` gem + custom Sass pipeline

#### Database

- PostgreSQL with `db.sh` helper script
- Use `rails db:seed` for initial data

### Code Conventions

#### Controllers

- Always call `authorize` before CRUD operations (Pundit requirement)
- Skip authentication with `skip_before_action :authenticate_user!` for public pages
- Use `respond_to do |format|` with Turbo Stream support for AJAX updates
- Admin controllers use `dashboard` layout

#### Forms

- SimpleForm DSL for all forms
- Bootstrap styling via `simple_form_bootstrap.rb`
- Specialty/profession dropdowns in member forms controlled by [memberFormSpecialty_controller.js](app/javascript/controllers/memberFormSpecialty_controller.js)

#### Error Pages

- Custom error handling in [errors_controller.rb](app/controllers/errors_controller.rb)
- `ErrorPolicy` controls error page access
- Graceful fallbacks with Romanian messaging

### Environment & Secrets

- **Cloudinary**: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`
- **Domain**: `DOMAIN` env var for mailers/SEO
- **Email**: Uses Postmark in production, Letter Opener in development

### Testing

- Minitest framework with system tests (Capybara + Selenium)
- Controllers, models, and policies have test coverage in [test/](test/)

## Common Tasks

### Add New Resource

1. Generate scaffold with Pundit policy: `rails g scaffold ResourceName --policy`
2. Add Romanian routes in [routes.rb](config/routes.rb)
3. Include `SlugHelper` and `CheckSlugHelper` if SEO URLs needed
4. Override `to_param` to return slug
5. Add `skip_before_action :authenticate_user!` for public pages
6. Use `has_rich_text :description` if rich editor needed

### Add Stimulus Controller

1. Create in `app/javascript/controllers/` with `_controller.js` suffix
2. Auto-registers via [index.js](app/javascript/controllers/index.js)
3. Wire to HTML with `data-controller="name"` and `data-action="event->name#method"`

### Update Cloudinary Images

- Reference existing patterns in `BkgPhotosHelper`
- Always use quality/width optimizations: `quality: 60, width: 1000, crop: "scale"`

#### Rules for Agent

- Treat every task with max attention.
- Generate a todo list.
- Ask if clarification is needed before proceeding.
- Always commit to github after completing a task & testing it & asking me if i'm satisfied, my answer with "Yes" must be always expected.

Copilot Chat – Solo Developer Workflow Rules

Use these rules to define how Copilot Chat should behave when you assign a task in a solo development workflow.

⸻

1. Generate a todo list.
   • Break down the task into clear, actionable steps.
   • Ensure each step is specific and achievable.

2. Clarify only when it matters
   • Ask clarifying questions only if ambiguity would materially affect correctness or design.
   • Prefer making reasonable assumptions over blocking progress.

3. Stay within intent
   • Solve exactly the task requested.
   • Do not introduce additional features, refactors, or dependencies unless they clearly reduce complexity or risk.

4. Practical production quality
   • Write clean, readable, idiomatic code.
   • Optimize for maintainability and future readability.
   • Handle realistic edge cases; avoid defensive overengineering.

5. Follow existing patterns (lightweight)
   • Match existing naming, structure, and style.
   • Improve consistency only when touching nearby code.

6. Make assumptions explicit
   • State assumptions briefly when they influence behavior or design.
   • Avoid hidden or implicit behavior.

7. Explanation discipline
   • Explain why something is done if it is non-obvious.
   • Avoid tutorials or commentary on trivial code.

8. Output discipline
   • If code is requested, output code only unless an explanation is explicitly requested.
   • Prefer a single, solid approach over multiple alternatives.

⸻

Commit Rules (Solo Dev)

9. Commit scope
   • Prefer small, coherent commits, but allow pragmatic grouping when context is shared.
   • Avoid mixing unrelated changes, but do not over-split unnecessarily.

10. Commit timing
    • Commit when a logical step is complete or when the code is in a safe, recoverable state.
    • Avoid long-lived uncommitted work.

11. Commit message style
    • Use imperative mood.
    • Optimize for future recall rather than team communication.
    • Do not mention Copilot, AI, or tooling.

Recommended format:

<short description of intent>

<optional note if context may be forgotten later>

Examples:
• Handle edge case when contract has no parties
• Refactor auth middleware for readability
• Add basic validation to invoice import

12. What to avoid
    • “WIP” commits unless intentionally checkpointing.
    • Vague messages such as “changes”, “updates”, or “fix stuff”.
    • Formatting-only commits unless explicitly intended.

13. Check before committing
    • Code runs or builds successfully.
    • No debug logs, TODOs, or dead code unless intentional.
    • The diff matches the stated purpose of the commit.

14. If commit help is requested
    • Propose practical commit boundaries, not academic ones.
    • Provide exact commit messages unless alternatives are explicitly requested.
