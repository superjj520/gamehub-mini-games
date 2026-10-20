export function rightsAssetsForScope(assets, scopeId) {
  if (!Array.isArray(assets) || typeof scopeId !== "string" || scopeId.length === 0) return [];
  return assets.filter((asset) => Array.isArray(asset.release_scope_ids) && asset.release_scope_ids.includes(scopeId));
}

export function rightsAssetIdsForScope(assets, scopeId) {
  return rightsAssetsForScope(assets, scopeId).map((asset) => asset.id);
}
