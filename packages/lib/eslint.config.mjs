// @ts-check

import eslint from "@eslint/js";
import tseslint from 'typescript-eslint';
import globals from "globals";

export default tseslint.config(
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.node, // Enables Node.js environment
      }
    }
  },
  {
    ignores: [
      'dist/**',       // Build output
      'node_modules/**',
      'coverage/**',   // Test coverage
      '.eslintrc.*'    // Old config files
    ]
  }
);
