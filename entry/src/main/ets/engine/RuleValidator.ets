import { AutomationRule, Condition, Device } from '../model/Types';
import { DeviceReader } from '../model/Readers';

export enum RuleErr {
  NAME_EMPTY = 'NAME_EMPTY',
  EMPTY_CONDITION = 'EMPTY_CONDITION',
  PRIORITY_RANGE = 'PRIORITY_RANGE',
  ORPHAN_DEVICE = 'ORPHAN_DEVICE',
  COOLDOWN_NEGATIVE = 'COOLDOWN_NEGATIVE',
  ACTION_EMPTY = 'ACTION_EMPTY'
}

export interface ValidationResult {
  ok: boolean;
  errors: string[];
  codes: string[];
}

/** 保存前校验：一次返回全部问题，调用方据此提示，不用反复试错 */
export class RuleValidator {
  static validate(rule: AutomationRule, devices: Device[]): ValidationResult {
    const errors: string[] = [];
    const codes: string[] = [];

    if (rule.name.trim().length === 0) {
      errors.push('规则名称不能为空');
      codes.push(RuleErr.NAME_EMPTY);
    }
    if (rule.conditionGroup.items.length === 0) {
      errors.push('至少需要一个条件');
      codes.push(RuleErr.EMPTY_CONDITION);
    }
    if (rule.priority < 1 || rule.priority > 99) {
      errors.push('优先级需在 1~99 之间');
      codes.push(RuleErr.PRIORITY_RANGE);
    }
    if (rule.cooldownMs < 0) {
      errors.push('冷却时间不能为负数');
      codes.push(RuleErr.COOLDOWN_NEGATIVE);
    }
    if (rule.actions.length === 0) {
      errors.push('至少需要一个设备动作');
      codes.push(RuleErr.ACTION_EMPTY);
    }
    for (let i = 0; i < rule.actions.length; i++) {
      const id: string = rule.actions[i].deviceId;
      if (DeviceReader.find(devices, id) === undefined) {
        errors.push(`动作指向的设备已删除：${id}`);
        codes.push(RuleErr.ORPHAN_DEVICE);
        break;
      }
    }
    for (let i = 0; i < rule.conditionGroup.items.length; i++) {
      const c: Condition = rule.conditionGroup.items[i];
      if (c.source === 'device' && DeviceReader.find(devices, c.deviceId) === undefined) {
        errors.push(`条件引用的设备已删除：${c.deviceId}`);
        codes.push(RuleErr.ORPHAN_DEVICE);
        break;
      }
    }
    return { ok: errors.length === 0, errors: errors, codes: codes };
  }
}
