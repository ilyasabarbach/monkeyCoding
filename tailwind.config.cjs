/** @type {import('tailwindcss').Config} */
module.exports = {
    content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
    theme: {
        extend: {
            colors: {
                crimson: '#DC143C',
                charcoal: '#121212',
            },
        },
    },
    plugins: [],
};
