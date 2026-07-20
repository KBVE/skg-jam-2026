/// <reference types="vite/client" />

// @kbve/laser@0.1.5 does not ship its declared index.d.ts.
// Ambient shim so TypeScript resolves the runtime exports.
// Remove once the package ships real types.
declare module '@kbve/laser';
