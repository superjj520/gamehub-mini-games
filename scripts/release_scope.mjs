const officeSegmentIds = Array.from({length: 10}, (_, index) => `office-${String(index + 1).padStart(2, "0")}`);
const citySegmentIds = Array.from({length: 11}, (_, index) => `city-${String(index + 1).padStart(2, "0")}`);
const sharedAssetIds = ["player-character", "three-wheel-vehicle", "interaction-props", "final-audio-library"];

export const scopeDefinitions = Object.freeze({
  office_vertical_slice: Object.freeze({
    segmentIds: Object.freeze(officeSegmentIds),
    assetIds: Object.freeze([...sharedAssetIds, "office-npc-set", "office-environment-kit"])
  }),
  office_and_city: Object.freeze({
    segmentIds: Object.freeze([...officeSegmentIds, ...citySegmentIds]),
    assetIds: Object.freeze([...sharedAssetIds, "office-npc-set", "office-environment-kit", "city-crowd-set", "city-environment-kit"])
  })
});

export function resolveScope(launchScope) {
  if (!Array.isArray(launchScope) || launchScope.length !== 1) return null;
  return scopeDefinitions[launchScope[0]] ?? null;
}
