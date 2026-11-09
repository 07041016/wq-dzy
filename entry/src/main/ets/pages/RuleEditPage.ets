import {
  AutomationRule, ChipItem, Condition, CondOp, Device, DeviceAction, EnvRange, PROP_RANGES
} from '../model/Types';
import { DeviceReader, EnvText } from '../model/Readers';
import { Defaults } from '../model/Defaults';
import { RuleValidator, ValidationResult } from '../engine/RuleValidator';
import { Boot } from '../viewmodel/Boot';
import { TickRunner } from '../viewmodel/TickRunner';
import { ChipRow } from '../components/ChipRow';
import { NumberField } from '../components/NumberField';
import { Ui } from '../common/Ui';

const ENV_KEYS: string[] = ['temperature', 'humidity', 'illuminance', 'noise'];
const OPS: string[] = [CondOp.GE, CondOp.GT, CondOp.LE, CondOp.LT, CondOp.EQ];
const OP_LABELS: string[] = ['≥', '>', '≤', '<', '='];

/**
 * 规则编辑器：名称 / 优先级 / 冷却 / 双条件组 / 最多三个动作。
 * 保存前由 RuleValidator 一次性给出全部问题。
 */
@Entry
@Component
struct RuleEditPage {
  @StorageProp('deviceList') devices: Device[] = Defaults.devices();
  @State ruleId: string = '';
  @State ruleName: string = '';
  @State priority: number = 70;
  @State cooldownMs: number = 60000;
  @State logic: string = 'and';
  @State hasSecond: boolean = true;
  @State c1Key: string = 'temperature';
  @State c1Op: string = CondOp.GE;
  @State c1Value: string = '28';
  @State c2Key: string = 'humidity';
  @State c2Op: string = CondOp.GE;
  @State c2Value: string = '65';
  @State actionCount: number = 2;
  @State a1Device: string = 'd-light-ceiling';
  @State a1Prop: string = 'power';
  @State a1Value: string = '1';
  @State a2Device: string = 'd-ac';
  @State a2Prop: string = 'temperature';
  @State a2Value: string = '26';
  @State a3Device: string = 'd-fan';
  @State a3Prop: string = 'speed';
  @State a3Value: string = '2';

  aboutToAppear(): void {
    const id: string = Ui.ruleIdParam(this.getUIContext());
    if (id.length > 0) {
      this.ruleId = id;
      this.loadRule(id);
    }
  }

  private loadRule(id: string): void {
    const rules: AutomationRule[] = Boot.rules();
    for (let i = 0; i < rules.length; i++) {
      if (rules[i].id !== id) {
        continue;
      }
      const r: AutomationRule = rules[i];
      this.ruleName = r.name;
      this.priority = r.priority;
      this.cooldownMs = r.cooldownMs;
      this.logic = r.conditionGroup.logic;
      const items: Condition[] = r.conditionGroup.items;
      if (items.length > 0) {
        this.c1Key = items[0].key;
        this.c1Op = items[0].op;
        this.c1Value = `${items[0].value}`;
      }
      this.hasSecond = items.length > 1;
      if (items.length > 1) {
        this.c2Key = items[1].key;
        this.c2Op = items[1].op;
        this.c2Value = `${items[1].value}`;
      }
      this.actionCount = r.actions.length;
      if (r.actions.length > 0) {
        this.a1Device = r.actions[0].deviceId;
        this.a1Prop = r.actions[0].property;
        this.a1Value = `${r.actions[0].value}`;
      }
      if (r.actions.length > 1) {
        this.a2Device = r.actions[1].deviceId;
        this.a2Prop = r.actions[1].property;
        this.a2Value = `${r.actions[1].value}`;
      }
      if (r.actions.length > 2) {
        this.a3Device = r.actions[2].deviceId;
        this.a3Prop = r.actions[2].property;
        this.a3Value = `${r.actions[2].value}`;
      }
      return;
    }
  }

  private envChips(): ChipItem[] {
    const out: ChipItem[] = [];
    for (let i = 0; i < ENV_KEYS.length; i++) {
      out.push({ value: ENV_KEYS[i], label: EnvText.of(ENV_KEYS[i]) });
    }
    return out;
  }

  private opChips(): ChipItem[] {
    const out: ChipItem[] = [];
    for (let i = 0; i < OPS.length; i++) {
      out.push({ value: OPS[i], label: OP_LABELS[i] });
    }
    return out;
  }

  private logicChips(): ChipItem[] {
    return [
      { value: 'and', label: '同时满足 AND' },
      { value: 'or', label: '任一满足 OR' }
    ];
  }

  private cooldownChips(): ChipItem[] {
    return [
      { value: '0', label: '无冷却' },
      { value: '30000', label: '30 s' },
      { value: '60000', label: '60 s' },
      { value: '120000', label: '120 s' }
    ];
  }

  private deviceChips(): ChipItem[] {
    const out: ChipItem[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      out.push({ value: this.devices[i].id, label: this.devices[i].name });
    }
    return out;
  }

  private propChips(deviceId: string): ChipItem[] {
    const out: ChipItem[] = [];
    const names: string[] = ['power'];
    const dev: Device | undefined = DeviceReader.find(this.devices, deviceId);
    if (dev !== undefined) {
      const keys: string[] = Object.keys(dev.props);
      for (let i = 0; i < keys.length; i++) {
        names.push(keys[i]);
      }
    }
    for (let i = 0; i < names.length; i++) {
      const range: EnvRange | undefined = PROP_RANGES[names[i]];
      out.push({ value: names[i], label: range === undefined ? names[i] : range.label });
    }
    return out;
  }

  private toNumber(text: string, fallback: number): number {
    const v: number = Number.parseFloat(text);
    return Number.isNaN(v) ? fallback : v;
  }

  private buildRule(): AutomationRule {
    const items: Condition[] = [];
    items.push({
      source: 'env', key: this.c1Key, deviceId: '', op: this.c1Op,
      value: this.toNumber(this.c1Value, 0)
    });
    if (this.hasSecond) {
      items.push({
        source: 'env', key: this.c2Key, deviceId: '', op: this.c2Op,
        value: this.toNumber(this.c2Value, 0)
      });
    }
    const actions: DeviceAction[] = [
      {
        deviceId: this.a1Device, property: this.a1Prop,
        value: this.toNumber(this.a1Value, 0)
      }
    ];
    if (this.actionCount > 1) {
      actions.push({
        deviceId: this.a2Device, property: this.a2Prop,
        value: this.toNumber(this.a2Value, 0)
      });
    }
    if (this.actionCount > 2) {
      actions.push({
        deviceId: this.a3Device, property: this.a3Prop,
        value: this.toNumber(this.a3Value, 0)
      });
    }
    const id: string = this.ruleId.length > 0
      ? this.ruleId
      : Defaults.newRuleId(Math.round(this.priority), Date.now() % 1000);
    return {
      id: id,
      name: this.ruleName.trim(),
      enabled: true,
      priority: Math.round(this.priority),
      cooldownMs: this.cooldownMs,
      createdSeq: Date.now() % 100000,
      conditionGroup: { logic: this.logic, items: items },
      actions: actions,
      updatedAt: Date.now()
    };
  }

  private async save(): Promise<void> {
    const rule: AutomationRule = this.buildRule();
    const result: ValidationResult = RuleValidator.validate(rule, this.devices);
    if (!result.ok) {
      Ui.toast(this.getUIContext(), result.errors[0]);
      return;
    }
    const list: AutomationRule[] = Boot.rules().slice();
    let replaced: boolean = false;
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === rule.id) {
        rule.enabled = list[i].enabled;
        rule.createdSeq = list[i].createdSeq;
        list[i] = rule;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      list.push(rule);
    }
    await Boot.saveRules(list);
    await TickRunner.tick();
    Ui.toast(this.getUIContext(), '已保存，规则已生效');
    Ui.back(this.getUIContext());
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor('#0F172A')
      .width('100%')
      .margin({ top: 4, bottom: 4 })
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Text('‹ 返回')
          .fontSize(13)
          .fontColor('#2563EB')
          .onClick(() => {
            Ui.back(this.getUIContext());
          })
        Text(this.ruleId.length > 0 ? '编辑规则' : '新建规则')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
        Text('保存')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#2563EB')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(12)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            this.sectionTitle('基本信息')
            TextInput({ text: this.ruleName, placeholder: '例如：夜间自习' })
              .fontSize(13)
              .height(38)
              .backgroundColor('#F7F9FC')
              .onChange((v: string) => {
                this.ruleName = v;
              })
            Row() {
              Text('优先级')
                .fontSize(11)
                .fontColor('#94A3B8')
                .width(52)
              Slider({ value: this.priority, min: 1, max: 99, step: 1 })
                .layoutWeight(1)
                .selectedColor('#2563EB')
                .onChange((v: number) => {
                  this.priority = v;
                })
              Text(`${Math.round(this.priority)}`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .width(30)
                .textAlign(TextAlign.End)
            }
            .width('100%')

            ChipRow({
              label: '冷却时间',
              items: this.cooldownChips(),
              current: `${this.cooldownMs}`,
              onPick: (v: string) => {
                this.cooldownMs = Number.parseInt(v);
              }
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Column({ space: 8 }) {
            this.sectionTitle('触发条件')

            ChipRow({
              label: '条件组合',
              items: this.logicChips(),
              current: this.logic,
              onPick: (v: string) => {
                this.logic = v;
              }
            })
            ChipRow({
              label: '条件一 · 环境量',
              items: this.envChips(),
              current: this.c1Key,
              onPick: (v: string) => {
                this.c1Key = v;
              }
            })
            ChipRow({
              label: '比较方式',
              items: this.opChips(),
              current: this.c1Op,
              onPick: (v: string) => {
                this.c1Op = v;
              }
            })
            NumberField({
              label: '阈值',
              value: this.c1Value,
              unit: EnvText.unitOf(this.c1Key),
              onValue: (v: string) => {
                this.c1Value = v;
              }
            })

            Row() {
              Text('启用第二个条件')
                .fontSize(12)
                .fontColor('#475569')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.hasSecond })
                .selectedColor('#2563EB')
                .onChange((isOn: boolean) => {
                  this.hasSecond = isOn;
                })
            }
            .width('100%')
            .margin({ top: 4 })

            if (this.hasSecond) {
              ChipRow({
                label: '条件二 · 环境量',
                items: this.envChips(),
                current: this.c2Key,
                onPick: (v: string) => {
                  this.c2Key = v;
                }
              })
              ChipRow({
                label: '比较方式',
                items: this.opChips(),
                current: this.c2Op,
                onPick: (v: string) => {
                  this.c2Op = v;
                }
              })
              NumberField({
                label: '阈值',
                value: this.c2Value,
                unit: EnvText.unitOf(this.c2Key),
                onValue: (v: string) => {
                  this.c2Value = v;
                }
              })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Column({ space: 8 }) {
            this.sectionTitle('设备动作')

            ChipRow({
              label: '动作一 · 设备',
              items: this.deviceChips(),
              current: this.a1Device,
              onPick: (v: string) => {
                this.a1Device = v;
                this.a1Prop = 'power';
              }
            })
            ChipRow({
              label: '动作一 · 属性',
              items: this.propChips(this.a1Device),
              current: this.a1Prop,
              onPick: (v: string) => {
                this.a1Prop = v;
              }
            })
            NumberField({
              label: '目标值',
              value: this.a1Value,
              unit: '',
              onValue: (v: string) => {
                this.a1Value = v;
              }
            })

            Row() {
              Text('启用第二、三个动作')
                .fontSize(12)
                .fontColor('#475569')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.actionCount > 1 })
                .selectedColor('#2563EB')
                .onChange((isOn: boolean) => {
                  this.actionCount = isOn ? 2 : 1;
                })
            }
            .width('100%')
            .margin({ top: 4 })

            if (this.actionCount > 1) {
              ChipRow({
                label: '动作二 · 设备',
                items: this.deviceChips(),
                current: this.a2Device,
                onPick: (v: string) => {
                  this.a2Device = v;
                  this.a2Prop = 'power';
                }
              })
              ChipRow({
                label: '动作二 · 属性',
                items: this.propChips(this.a2Device),
                current: this.a2Prop,
                onPick: (v: string) => {
                  this.a2Prop = v;
                }
              })
              NumberField({
                label: '目标值',
                value: this.a2Value,
                unit: '',
                onValue: (v: string) => {
                  this.a2Value = v;
                }
              })
            }

            if (this.actionCount > 2) {
              ChipRow({
                label: '动作三 · 设备',
                items: this.deviceChips(),
                current: this.a3Device,
                onPick: (v: string) => {
                  this.a3Device = v;
                  this.a3Prop = 'power';
                }
              })
              ChipRow({
                label: '动作三 · 属性',
                items: this.propChips(this.a3Device),
                current: this.a3Prop,
                onPick: (v: string) => {
                  this.a3Prop = v;
                }
              })
              NumberField({
                label: '目标值',
                value: this.a3Value,
                unit: '',
                onValue: (v: string) => {
                  this.a3Value = v;
                }
              })
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Text('说明：优先级数值越大越先执行；同一设备的同一属性只会有一条规则生效，'
            + '被挤掉的规则会记录在执行日志的「冲突」里。')
            .fontSize(11)
            .fontColor('#94A3B8')
            .width('100%')
            .padding({ left: 4, right: 4 })
        }
        .padding({ left: 14, right: 14, bottom: 24, top: 4 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }
}
