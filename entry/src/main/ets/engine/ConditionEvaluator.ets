import { CondOp, CondSource, Condition, ConditionGroup, Device, EnvSnapshot } from '../model/Types';
import { DeviceReader, EnvReader } from '../model/Readers';

/**
 * 条件求值：纯函数，只读快照。
 * 遇到 NaN、缺字段、未知算子一律返回 false，绝不抛异常中断 tick。
 */
export class ConditionEvaluator {
  static evalGroup(group: ConditionGroup, env: EnvSnapshot, devices: Device[]): boolean {
    if (group.items.length === 0) {
      return false;
    }
    if (group.logic === 'or') {
      for (let i = 0; i < group.items.length; i++) {
        if (ConditionEvaluator.evalOne(group.items[i], env, devices)) {
          return true;
        }
      }
      return false;
    }
    for (let i = 0; i < group.items.length; i++) {
      if (!ConditionEvaluator.evalOne(group.items[i], env, devices)) {
        return false;
      }
    }
    return true;
  }

  /** 取条件左值：环境量或设备属性 */
  static actualOf(c: Condition, env: EnvSnapshot, devices: Device[]): number {
    if (c.source === CondSource.ENV) {
      return EnvReader.read(env, c.key);
    }
    const dev: Device | undefined = DeviceReader.find(devices, c.deviceId);
    if (dev === undefined) {
      return NaN;
    }
    return DeviceReader.read(dev, c.key);
  }

  static evalOne(c: Condition, env: EnvSnapshot, devices: Device[]): boolean {
    const actual: number = ConditionEvaluator.actualOf(c, env, devices);
    if (Number.isNaN(actual)) {
      return false;
    }
    switch (c.op) {
      case CondOp.GT:
        return actual > c.value;
      case CondOp.GE:
        return actual >= c.value;
      case CondOp.LT:
        return actual < c.value;
      case CondOp.LE:
        return actual <= c.value;
      case CondOp.EQ:
        return actual === c.value;
      default:
        return false;
    }
  }
}
