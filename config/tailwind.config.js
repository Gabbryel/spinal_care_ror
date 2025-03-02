const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,html,html.erb}",
  ],
  theme: {
    extend: {
      colors: {
        // colorNavbar: "#1b2a31",
        "cl-navbar": "#4a6775",
        "cl-bg": "#fff",
        "cl-txt-light": "#fff",
        "cl-light-blue": "#cedae1",
        "colorNavbar-90": "#1c2b33ac",
        golden: "#bab28a",
        feldgrau: "#4a5b5c",
        "jungle-green": "#17211A",
        "text-color": "#fff6d3",
      },
      screens: {
        xs: "500px",
      },
      fontFamily: {
        sans: ["Inter var", ...defaultTheme.fontFamily.sans],
        montserrat: ["Montserrat", ...defaultTheme.fontFamily.sans],
        poppins: ["Poppins", ...defaultTheme.fontFamily.sans],
      },

      gridTemplateRows: {
        medicalServices: "repeat(auto-fit, minmax(1000px, auto))",
      },
      dropShadow: {
        custom: "1px 1px 1px #0a0a0ab3",
        hover: "2px 2px 1px #0a0a0ab6",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("@tailwindcss/container-queries"),
  ],
};
