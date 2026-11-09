import {
  CondOp, CondSource, Condition, ConditionGroup, Device, DeviceAction, EnvSnapshot
} from '../model/Types';
import { DeviceReader, EnvReader, EnvText, Fmt } from '../model/Readers';
import { ConditionEvaluator } from './ConditionEvaluator';

/** 把条件 AST 变成人能读的中文，规则卡片与执行日志共用 */
export class ConditionTextBuilder {
  static toRuleText(group: ConditionGroup): string {
    if (group.items.length === 0) {
      return '（未设置条件）';
    }
    const parts: string[] = [];
    for (let i = 0; i < group.items.length; i++) {
      parts.push(ConditionTextBuilder.rulePart(group.items[i]));
    }
    return parts.join(group.logic === 'or' ? ' 或 ' : ' 且 ');
  }

  /** 日志用：带上实际值，例如“光照 140 ≤ 150 lx 且 噪声 42 ≤ 45 dB” */
  static toLogText(group: ConditionGroup, env: EnvSnapshot, devices: Device[]): string {
    if (group.items.length === 0) {
      return '（未设置条件）';
    }
    const parts: string[] = [];
    for (let i = 0; i < group.items.length; i++) {
      parts.push(ConditionTextBuilder.logPart(group.items[i], env, devices));
    }
    return parts.join(group.logic === 'or' ? ' 或 ' : ' 且 ');
  }

  static rulePart(c: Condition): string {
    if (c.source === CondSource.ENV) {
      const unit: string = EnvText.unitOf(c.key);
      return `${EnvText.of(c.key)} ${Fmt.condOpText(c.op, c.value, unit, c.key)}`;
    }
    const unit: string = c.key === 'power' ? '' : Fmt.devicePropUnit(c.key);
    return `设备 ${c.key} ${Fmt.condOpText(c.op, c.value, unit, c.key)}`;
  }

  static logPart(c: Condition, env: EnvSnapshot, devices: Device[]): string {
    const actual: number = ConditionEvaluator.actualOf(c, env, devices);
    const unit: string = c.source === CondSource.ENV ? EnvText.unitOf(c.key) : '';
    const label: string = c.source === CondSource.ENV ? EnvText.of(c.key) : ConditionTextBuilder.deviceName(c, devices);
    const shown: string = Number.isNaN(actual) ? '--' : Fmt.num(actual, 1);
    const target: string = Fmt.condOpText(c.op, c.value, unit, c.key);
    return `${label} ${shown} ${target}`;
  }

  static deviceName(c: Condition, devices: Device[]): string {
    const dev: Device | undefined = DeviceReader.find(devices, c.deviceId);
    if (dev === undefined) {
      return c.key;
    }
    return `${dev.name}.${c.key}`;
  }

  static actionText(act: DeviceAction, devices: Device[]): string {
    const dev: Device | undefined = DeviceReader.find(devices, act.deviceId);
    const name: string = dev === undefined ? act.deviceId : dev.name;
    if (act.property === 'power') {
      return `${name} ${act.value !== 0 ? '开' : '关'}`;
    }
    const unit: string = Fmt.devicePropUnit(act.property);
    return `${name} ${Fmt.num(act.value, 0)}${unit}`;
  }

  static actionsText(actions: DeviceAction[], devices: Device[]): string {
    if (actions.length === 0) {
      return '（无动作）';
    }
    const parts: string[] = [];
    for (let i = 0; i < actions.length; i++) {
      parts.push(ConditionTextBuilder.actionText(actions[i], devices));
    }
    return parts.join('；');
  }

  static opOf(value: string): string {
    return value === CondOp.GE ? '≥' : value;
  }

  static envUnitOf(key: string): string {
    return EnvText.unitOf(key);
  }
}
