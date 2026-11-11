import { withMermaid } from 'vitepress-plugin-mermaid'
import apiSidebar from '../api/_sidebar.json'

// one sidebar, in reading order, for the guide and the manual: prev/next links walk the whole documentation
const docs = [
  {
    text: 'Start here',
    items: [
      { text: 'About',        link: '/guide/' },
      { text: 'Installation', link: '/guide/install' },
      { text: 'Showcase',     link: '/guide/showcase' },
    ],
  },
  {
    text: 'Tutorial, part one: the basics',
    items: [
      { text: 'Overview',                     link: '/manual/' },
      { text: '1. A first window',            link: '/manual/tutorial/01-first-window' },
      { text: '2. Widgets and state',         link: '/manual/tutorial/02-widgets' },
      { text: '3. Plots',                     link: '/manual/tutorial/03-plots' },
      { text: '4. A live computation',        link: '/manual/tutorial/04-live' },
      { text: '5. Testing without a display', link: '/manual/tutorial/05-headless' },
      { text: '6. Running work',              link: '/manual/tutorial/06-running-work' },
    ],
  },
  {
    text: 'Tutorial, part two: a solver studio',
    items: [
      { text: '7. The studio\'s own window',   link: '/manual/tutorial/07-window' },
      { text: '8. The application\'s shell',   link: '/manual/tutorial/08-shell' },
      { text: '9. The case',                  link: '/manual/tutorial/09-case' },
      { text: '10. The input editor',         link: '/manual/tutorial/10-input' },
      { text: '11. Running the solver',       link: '/manual/tutorial/11-run' },
      { text: '12. The result field',         link: '/manual/tutorial/12-field' },
      { text: '13. The field in 3-D',         link: '/manual/tutorial/13-view3d' },
      { text: '14. Heavy work off the frame', link: '/manual/tutorial/14-task' },
      { text: '15. Robustness',               link: '/manual/tutorial/15-robust' },
      { text: '16. The studio tested',        link: '/manual/tutorial/16-tested' },
      { text: '17. The studio on a cluster',  link: '/manual/tutorial/17-remote' },
    ],
  },
  {
    text: 'Tutorial, part three: the studio grows',
    items: [
      { text: '18. Mistakes and keys',        link: '/manual/tutorial/18-checks' },
      { text: '19. Fields, lists and sizes',  link: '/manual/tutorial/19-layout' },
      { text: '20. Tables that act',          link: '/manual/tutorial/20-tables' },
      { text: '21. A sketch and a monitor',   link: '/manual/tutorial/21-monitor' },
      { text: '22. The field and its snapshots', link: '/manual/tutorial/22-player' },
      { text: '23. Windows and layouts',      link: '/manual/tutorial/23-windows' },
      { text: '24. An editor and the help',   link: '/manual/tutorial/24-editor' },
      { text: '25. A clip plane, a picture test', link: '/manual/tutorial/25-clip' },
    ],
  },
  {
    text: 'Recipes',
    items: [
      { text: 'Cookbook', link: '/manual/cookbook' },
    ],
  },
  {
    text: 'Reference',
    items: [
      { text: 'Feature map',             link: '/guide/features' },
      { text: 'Frame loop and redraw',   link: '/guide/frame-loop' },
      { text: 'Widgets',                 link: '/guide/widgets' },
      { text: 'Menus and popups',        link: '/guide/menus' },
      { text: 'Docking',                 link: '/guide/docking' },
      { text: 'Styles',                  link: '/guide/styles' },
      { text: 'Plots',                   link: '/guide/plots' },
      { text: 'Heatmaps and images',     link: '/guide/images' },
      { text: 'Colormaps',               link: '/guide/colormaps' },
      { text: '3-D views',               link: '/guide/view3d' },
      { text: 'Code editor',             link: '/guide/editor' },
      { text: 'Canvas',                  link: '/guide/canvas' },
      { text: 'Processes and tasks',     link: '/guide/processes' },
      { text: 'Remote UI',               link: '/guide/remote' },
      { text: 'Performance',             link: '/guide/performance' },
      { text: 'Error handling',          link: '/guide/errors' },
      { text: 'Headless testing',        link: '/guide/testing' },
      { text: 'Screenshots and videos',  link: '/guide/capture' },
      { text: 'Architecture',            link: '/guide/architecture' },
      { text: 'Raw bindings',            link: '/guide/raw-bindings' },
      { text: 'Dear ImGui names',        link: '/guide/imgui-names' },
      { text: 'Known issues',            link: '/guide/known-issues' },
    ],
  },
  {
    text: 'Project',
    items: [
      { text: 'Why immediate mode', link: '/guide/why' },
      { text: 'Roadmap',            link: '/guide/roadmap' },
      { text: 'API Reference',      link: '/guide/api-reference' },
      { text: 'Contributing',       link: '/guide/contributing' },
      { text: 'Changelog',          link: '/guide/changelog' },
    ],
  },
]

export default withMermaid({
  title: 'FIGURE',
  description: 'Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration',
  base: '/figure/',
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/figure/favicon.svg' }]],
  // ford.md is the formal project file, not a page; the examples are included by the pages, not pages themselves
  srcExclude: ['ford.md', 'examples/**'],

  markdown: {
    math: true,
    languages: ['fortran-free-form', 'fortran-fixed-form'],
    languageAlias: {
      fortran: 'fortran-free-form',
      f90: 'fortran-free-form',
      F90: 'fortran-free-form',
      f03: 'fortran-free-form',
      f08: 'fortran-free-form',
    },
  },

  themeConfig: {
    logo: { light: '/logo.svg', dark: '/logo-dark.svg', alt: 'FIGURE logo' },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Start here', link: '/guide/', activeMatch: '^/guide/(index|install|showcase)?$' },
      { text: 'Tutorial', link: '/manual/tutorial/01-first-window', activeMatch: '^/manual/(index|tutorial/)' },
      { text: 'Cookbook', link: '/manual/cookbook', activeMatch: '^/manual/cookbook' },
      {
        text: 'Reference',
        link: '/guide/features',
        activeMatch: '^/guide/(features|frame-loop|widgets|menus|docking|styles|plots|images|view3d|editor|canvas|remote|performance|errors|testing|capture|architecture|raw-bindings|imgui-names|known-issues)',
      },
      { text: 'API', link: '/api/' },
      {
        text: 'Project',
        items: [
          { text: 'Why immediate mode', link: '/guide/why' },
          { text: 'Roadmap',            link: '/guide/roadmap' },
          { text: 'Contributing',       link: '/guide/contributing' },
          { text: 'Changelog',          link: '/guide/changelog' },
        ],
      },
    ],

    sidebar: {
      '/guide/': docs,
      '/manual/': docs,
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
          ],
        },
        ...apiSidebar,
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/szaghi/figure' },
    ],

    search: {
      provider: 'local',
    },

    outline: [2, 3],

    footer: {
      message: 'Released under the MIT licence.',
      copyright: 'Copyright © 2026 Stefano Zaghi',
    },
  },

  mermaid: {},

  vite: {
    // Build with an explicit modern JS target so the docs compile regardless of
    // which mermaid/vitepress/esbuild versions npm resolves. Vite's default
    // es2020 target forces esbuild to down-level modern syntax (e.g. the
    // destructuring mermaid 11.16+ emits), which it refuses to do and the build
    // dies. es2022 needs no lowering and is within VitePress's browser floor.
    build: {
      target: 'es2022',
    },
  },
})
