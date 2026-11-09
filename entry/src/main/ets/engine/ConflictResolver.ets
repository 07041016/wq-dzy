import {
  AutomationRule, ConflictItem, Device, DeviceAction, ResolvedStep, ResolveResult,
  RuleRuntimeState
} from '../model/Types';
import { DeviceReader } from '../model/Readers';

/**
 * 冲突消解：同一 targetKey（deviceId.property）只允许一条规则生效。
 * 规则：priority 降序 → createdSeq 升序；同值写入按幂等跳过；冷却期内跳过但留痕。
 */
export class ConflictResolver {
  static sortByPriority(rules: AutomationRule[]): AutomationRule[] {
    const copy: AutomationRule[] = rules.slice();
    copy.sort((a: AutomationRule, b: AutomationRule): number => {
      if (b.priority !== a.priority) {
        return b.priority - a.priority;
      }
      return a.createdSeq - b.createdSeq;
    });
    return copy;
  }

  static resolve(rules: AutomationRule[], devices: Device[],
    runtime: Map<string, RuleRuntimeState>, now: number): ResolveResult {
    const claimed: Map<string, AutomationRule> = new Map<string, AutomationRule>();
    const steps: ResolvedStep[] = [];
    const conflicts: ConflictItem[] = [];

    for (let i = 0; i < rules.length; i++) {
      const rule: AutomationRule = rules[i];
      const remain: number = ConflictResolver.cooldownRemain(rule, runtime, now);
      if (remain > 0) {
        steps.push({ rule: rule, actions: [], skipped: true, cooldownRemainMs: remain });
        continue;
      }
      const accepted: DeviceAction[] = [];
      for (let j = 0; j < rule.actions.length; j++) {
        const act: DeviceAction = rule.actions[j];
        const key: string = `${act.deviceId}.${act.property}`;
        const owner: AutomationRule | undefined = claimed.get(key);
        if (owner !== undefined) {
          conflicts.push({
            ruleId: rule.id, ruleName: rule.name, targetKey: key, want: act.value,
            keptBy: owner.id, keptPriority: owner.priority
          });
          continue;
        }
        claimed.set(key, rule);
        if (!ConflictResolver.isIdempotent(act, devices)) {
          accepted.push(act);
        }
      }
      steps.push({ rule: rule, actions: accepted, skipped: false, cooldownRemainMs: 0 });
    }
    return { steps: steps, conflicts: conflicts };
  }

  /** 目标值与当前值相同：不产生动作，也不写噪声日志 */
  static isIdempotent(act: DeviceAction, devices: Device[]): boolean {
    const dev: Device | undefined = DeviceReader.find(devices, act.deviceId);
    if (dev === undefined) {
      return true;
    }
    const current: number = DeviceReader.read(dev, act.property);
    if (Number.isNaN(current)) {
      return false;
    }
    return current === act.value;
  }

  static cooldownRemain(rule: AutomationRule, runtime: Map<string, RuleRuntimeState>,
    now: number): number {
    if (rule.cooldownMs <= 0) {
      return 0;
    }
    const state: RuleRuntimeState | undefined = runtime.get(rule.id);
    if (state === undefined) {
      return 0;
    }
    const used: number = now - state.lastTriggeredAt;
    if (used >= rule.cooldownMs) {
      return 0;
    }
    return rule.cooldownMs - used;
  }
}
