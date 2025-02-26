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
    },
    files: ["**/*.ts", "**/*.tsx"],
  }
);
