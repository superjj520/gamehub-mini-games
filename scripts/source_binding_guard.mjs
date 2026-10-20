export function assertSourceBinding(record, label, expectedFingerprint, expectedFileCount) {
  if (!record || typeof record !== "object") {
    throw new Error(`${label} 缺少采集记录，拒绝同步视觉证据`);
  }
  if (record.source_fingerprint !== expectedFingerprint || record.source_file_count !== expectedFileCount) {
    throw new Error(
      `${label} 源指纹与当前运行时不一致，拒绝同步旧 PNG：` +
        `record=${record.source_fingerprint ?? "missing"}/${record.source_file_count ?? "missing"} ` +
        `current=${expectedFingerprint}/${expectedFileCount}`,
    );
  }
}
