/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
	theme: {
		extend: {
			height: {
				'custom-calc': 'calc(100vh - 80px)',
				'custom--calc': 'calc(100vh - 102px)'
			},
			fontFamily: {
				serif: ['Figtree Variable', ...defaultTheme.fontFamily.serif],
				sans: ['Playfair Display Variable', ...defaultTheme.fontFamily.sans]
			},
			colors: {
				'rose': {
					'50': '#fef1f9',
					'100': '#fee5f5',
					'200': '#ffcbed',
					'300': '#ffa1dd',
					'400': '#ff67c4',
					'500': '#fa3aa9',
					'600': '#ec268f',
					'700': '#cc0a6c',
					'800': '#a90b59',
					'900': '#8c0f4c',
					'950': '#56012a',
				},

			}
		},
	},
	plugins: {
		
		"@tailwindcss/postcss": {},
	},
}
