const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,html}",
  ],
  theme: {
    extend: {
      colors: {
        colorNavbar: "#1c2b33",
        'colorNavbar-90': "#1c2b33ac",
        'golden': "#bab28a",
        'feldgrau': "#4a5b5c",
        'jungle-green': "#17211A",
      },
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
      },
      gridTemplateRows: {
        'medicalServices': 'repeat(auto-fit, minmax(1000px, auto))',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ],
};
