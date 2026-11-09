import {
  AutomationRule, CondOp, CondSource, Device, DeviceKind, EnvSnapshot, SceneProfile
} from './Types';

/**
 * 种子数据：首次启动（或 schemaVersion 不符）时使用。
 * 5 台设备 / 6 条规则 / 3 组场景，与需求说明书一致。
 */
export class Defaults {
  static devices(): Device[] {
    const now: number = Date.now();
    return [
      {
        id: 'd-light-ceiling', kind: DeviceKind.LIGHT, name: '顶灯', room: 'A-302',
        power: true, props: { 'brightness': 80, 'colorTemp': 4000 }, updatedAt: now
      },
      {
        id: 'd-light-bed', kind: DeviceKind.LIGHT, name: '床头灯', room: 'A-302',
        power: false, props: { 'brightness': 60, 'colorTemp': 3000 }, updatedAt: now
      },
      {
        id: 'd-ac', kind: DeviceKind.AC, name: '空调', room: 'A-302',
        power: true, props: { 'temperature': 26 }, updatedAt: now
      },
      {
        id: 'd-fan', kind: DeviceKind.FAN, name: '风扇', room: 'A-302',
        power: true, props: { 'speed': 2 }, updatedAt: now
      },
      {
        id: 'd-curtain', kind: DeviceKind.CURTAIN, name: '窗帘', room: 'A-302',
        power: true, props: { 'position': 0 }, updatedAt: now
      }
    ];
  }

  static env(): EnvSnapshot {
    return { temperature: 28.4, humidity: 66, illuminance: 140, noise: 42, updatedAt: Date.now() };
  }

  static rules(): AutomationRule[] {
    const now: number = Date.now();
    return [
      {
        id: 'R-94', name: '夜间自习', enabled: true, priority: 94,
        cooldownMs: 60000, createdSeq: 1,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'illuminance', deviceId: '', op: CondOp.LE, value: 150 },
            { source: CondSource.ENV, key: 'noise', deviceId: '', op: CondOp.LE, value: 45 }
          ]
        },
        actions: [
          { deviceId: 'd-light-ceiling', property: 'power', value: 1 },
          { deviceId: 'd-light-ceiling', property: 'brightness', value: 80 },
          { deviceId: 'd-ac', property: 'temperature', value: 26 }
        ],
        updatedAt: now
      },
      {
        id: 'R-88', name: '高温通风', enabled: true, priority: 88,
        cooldownMs: 30000, createdSeq: 2,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'temperature', deviceId: '', op: CondOp.GE, value: 28 }
          ]
        },
        actions: [
          { deviceId: 'd-ac', property: 'power', value: 1 },
          { deviceId: 'd-ac', property: 'temperature', value: 26 },
          { deviceId: 'd-fan', property: 'power', value: 1 },
          { deviceId: 'd-fan', property: 'speed', value: 2 }
        ],
        updatedAt: now
      },
      {
        id: 'R-75', name: '晨起透光', enabled: true, priority: 75,
        cooldownMs: 0, createdSeq: 3,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'illuminance', deviceId: '', op: CondOp.GE, value: 800 }
          ]
        },
        actions: [
          { deviceId: 'd-curtain', property: 'position', value: 70 },
          { deviceId: 'd-light-ceiling', property: 'power', value: 0 }
        ],
        updatedAt: now
      },
      {
        id: 'R-60', name: '午休助眠', enabled: true, priority: 60,
        cooldownMs: 120000, createdSeq: 4,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'temperature', deviceId: '', op: CondOp.GE, value: 28 },
            { source: CondSource.ENV, key: 'humidity', deviceId: '', op: CondOp.GE, value: 65 }
          ]
        },
        actions: [
          { deviceId: 'd-light-ceiling', property: 'brightness', value: 40 },
          { deviceId: 'd-curtain', property: 'position', value: 0 }
        ],
        updatedAt: now
      },
      {
        id: 'R-45', name: '闷湿排风', enabled: false, priority: 45,
        cooldownMs: 60000, createdSeq: 5,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'humidity', deviceId: '', op: CondOp.GE, value: 80 }
          ]
        },
        actions: [
          { deviceId: 'd-fan', property: 'power', value: 1 },
          { deviceId: 'd-fan', property: 'speed', value: 3 }
        ],
        updatedAt: now
      },
      {
        id: 'R-30', name: '离舍断电', enabled: true, priority: 30,
        cooldownMs: 0, createdSeq: 6,
        conditionGroup: {
          logic: 'and',
          items: [
            { source: CondSource.ENV, key: 'illuminance', deviceId: '', op: CondOp.LE, value: 50 },
            { source: CondSource.ENV, key: 'noise', deviceId: '', op: CondOp.LE, value: 30 }
          ]
        },
        actions: [
          { deviceId: 'd-light-ceiling', property: 'power', value: 0 },
          { deviceId: 'd-ac', property: 'power', value: 0 },
          { deviceId: 'd-fan', property: 'power', value: 0 }
        ],
        updatedAt: now
      }
    ];
  }

  /** 3 组预设场景：午休 / 夜读 / 离舍 */
  static scenes(): SceneProfile[] {
    const now: number = Date.now();
    return [
      {
        id: 'S-noon', name: '午休', createdAt: now,
        env: { temperature: 30, humidity: 72, illuminance: 120, noise: 38, updatedAt: now },
        devices: Defaults.devices()
      },
      {
        id: 'S-read', name: '夜读', createdAt: now,
        env: { temperature: 24, humidity: 55, illuminance: 140, noise: 42, updatedAt: now },
        devices: Defaults.devices()
      },
      {
        id: 'S-leave', name: '离舍', createdAt: now,
        env: { temperature: 29, humidity: 60, illuminance: 40, noise: 25, updatedAt: now },
        devices: Defaults.devices()
      }
    ];
  }

  static newRuleId(priority: number, seq: number): string {
    return `R-${priority}-${seq}`;
  }
}
