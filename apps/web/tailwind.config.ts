import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        flightpath: {
          black: "#050505",
          pink: "#FF10F0",
        },
      },
    },
  },
  plugins: [],
};

export default config;
