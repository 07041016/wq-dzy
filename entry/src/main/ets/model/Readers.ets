import { CondOp, CondSource, Condition, ConditionGroup, Device, EnvKey, EnvRange,
  EnvSnapshot, ENV_RANGES, PROP_RANGES } from './Types';

/** 环境快照的读取与 clamp，避免在业务代码里到处写 switch */
export class EnvReader {
  static read(env: EnvSnapshot, key: string): number {
    switch (key) {
      case EnvKey.TEMPERATURE:
        return env.temperature;
      case EnvKey.HUMIDITY:
        return env.humidity;
      case EnvKey.ILLUMINANCE:
        return env.illuminance;
      case EnvKey.NOISE:
        return env.noise;
      default:
        return NaN;
    }
  }

  /** 越界值先 clamp 再比较，等价于“真实环境不可能超出量程” */
  static clamp(key: string, value: number): number {
    const range: EnvRange | undefined = ENV_RANGES[key];
    if (range === undefined || Number.isNaN(value)) {
      return value;
    }
    if (value < range.min) {
      return range.min;
    }
    if (value > range.max) {
      return range.max;
    }
    return value;
  }

  static rangeOf(key: string): EnvRange {
    const range: EnvRange | undefined = ENV_RANGES[key];
    return range === undefined
      ? { min: 0, max: 100, unit: '', label: key }
      : range;
  }

  static defaultSnapshot(): EnvSnapshot {
    return { temperature: 24, humidity: 55, illuminance: 300, noise: 38, updatedAt: Date.now() };
  }
}

/** 设备属性的读写：power 是布尔字段，其余属性统一放在 props 里当数值处理 */
export class DeviceReader {
  static find(devices: Device[], id: string): Device | undefined {
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].id === id) {
        return devices[i];
      }
    }
    return undefined;
  }

  static read(dev: Device, property: string): number {
    if (property === 'power') {
      return dev.power ? 1 : 0;
    }
    const value: number | undefined = dev.props[property];
    return value === undefined ? NaN : value;
  }

  static write(dev: Device, property: string, value: number): void {
    if (property === 'power') {
      dev.power = value !== 0;
      return;
    }
    dev.props[property] = value;
  }

  static clampProp(property: string, value: number): number {
    const range: EnvRange | undefined = PROP_RANGES[property];
    if (range === undefined) {
      return value;
    }
    if (value < range.min) {
      return range.min;
    }
    if (value > range.max) {
      return range.max;
    }
    return value;
  }

  static clone(dev: Device): Device {
    const props: Record<string, number> = {};
    const keys: string[] = Object.keys(dev.props);
    for (let i = 0; i < keys.length; i++) {
      props[keys[i]] = dev.props[keys[i]];
    }
    return {
      id: dev.id, kind: dev.kind, name: dev.name, room: dev.room,
      power: dev.power, props: props, updatedAt: dev.updatedAt
    };
  }

  static cloneAll(devices: Device[]): Device[] {
    const out: Device[] = [];
    for (let i = 0; i < devices.length; i++) {
      out.push(DeviceReader.clone(devices[i]));
    }
    return out;
  }

  static findProperty(dev: Device, property: string): number {
    return DeviceReader.read(dev, property);
  }
}

export class EnvText {
  static of(key: string): string {
    return EnvReader.rangeOf(key).label;
  }

  static unitOf(key: string): string {
    return EnvReader.rangeOf(key).unit;
  }
}

export class Fmt {
  static num(value: number, digits: number): string {
    if (Number.isNaN(value)) {
      return '--';
    }
    const fixed: string = value.toFixed(digits);
    if (digits === 0) {
      return fixed;
    }
    // 去掉多余的 0：28.40 -> 28.4
    let out: string = fixed;
    while (out.endsWith('0')) {
      out = out.substring(0, out.length - 1);
    }
    if (out.endsWith('.')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  static time(ts: number): string {
    const d: Date = new Date(ts);
    const hh: string = Fmt.pad2(d.getHours());
    const mm: string = Fmt.pad2(d.getMinutes());
    const ss: string = Fmt.pad2(d.getSeconds());
    return `${hh}:${mm}:${ss}`;
  }

  static pad2(v: number): string {
    return v < 10 ? `0${v}` : `${v}`;
  }

  static power(on: boolean): string {
    return on ? '开' : '关';
  }

  static devicePropUnit(prop: string): string {
    const range: EnvRange | undefined = PROP_RANGES[prop];
    return range === undefined ? '' : range.unit;
  }

  static deviceProp(dev: Device, property: string): string {
    const value: number = DeviceReader.read(dev, property);
    if (property === 'power') {
      return value !== 0 ? '开' : '关';
    }
    const range: EnvRange | undefined = PROP_RANGES[property];
    const unit: string = range === undefined ? '' : range.unit;
    return `${Fmt.num(value, 0)}${unit}`;
  }

  static condOpText(op: string, value: number, unit: string, key: string): string {
    const v: string = key === 'power' ? (value !== 0 ? '开' : '关') : `${Fmt.num(value, 1)}${unit}`;
    switch (op) {
      case CondOp.GE:
        return `≥ ${v}`;
      case CondOp.GT:
        return `> ${v}`;
      case CondOp.LE:
        return `≤ ${v}`;
      case CondOp.LT:
        return `< ${v}`;
      case CondOp.EQ:
        return `= ${v}`;
      default:
        return op;
    }
  }

  static condSource(c: Condition): string {
    return c.source === CondSource.ENV ? '环境' : '设备';
  }

  static groupSummary(group: ConditionGroup): string {
    if (group.items.length === 0) {
      return '（未设置条件）';
    }
    const parts: string[] = [];
    for (let i = 0; i < group.items.length; i++) {
      const c: Condition = group.items[i];
      parts.push(`${c.source === CondSource.ENV ? EnvText.of(c.key) : c.key}`);
    }
    return parts.join(group.logic === 'or' ? ' 或 ' : ' 且 ');
  }
}
