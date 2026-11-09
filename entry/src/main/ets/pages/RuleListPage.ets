import { AutomationRule, Device } from '../model/Types';
import { Defaults } from '../model/Defaults';
import { ConditionTextBuilder } from '../engine/ConditionTextBuilder';
import { Boot } from '../viewmodel/Boot';
import { TickRunner } from '../viewmodel/TickRunner';
import { Ui } from '../common/Ui';

/**
 * 规则列表：优先级降序排列，顶部给出冲突提示；开关直接决定引擎的候选集。
 */
@Component
export struct RuleListPage {
  @StorageLink('ruleList') rules: AutomationRule[] = Defaults.rules();
  @StorageProp('deviceList') devices: Device[] = Defaults.devices();
  @StorageProp('conflictTip') conflictTip: string = '';

  private sorted(): AutomationRule[] {
    const copy: AutomationRule[] = this.rules.slice();
    copy.sort((a: AutomationRule, b: AutomationRule): number => {
      if (b.priority !== a.priority) {
        return b.priority - a.priority;
      }
      return a.createdSeq - b.createdSeq;
    });
    return copy;
  }

  private enabledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].enabled) {
        n++;
      }
    }
    return n;
  }

  private toggleRule(rule: AutomationRule, enabled: boolean): void {
    const list: AutomationRule[] = this.rules.slice();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === rule.id) {
        const updated: AutomationRule = {
          id: list[i].id, name: list[i].name, enabled: enabled,
          priority: list[i].priority, cooldownMs: list[i].cooldownMs,
          createdSeq: list[i].createdSeq, conditionGroup: list[i].conditionGroup,
          actions: list[i].actions, updatedAt: Date.now()
        };
        list[i] = updated;
      }
    }
    this.rules = list;
    Boot.saveRules(list);
    TickRunner.tick();
  }

  private openEditor(ruleId: string): void {
    Ui.pushRuleEditor(this.getUIContext(), ruleId);
  }

  @Builder
  ruleCard(rule: AutomationRule) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(rule.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
        Text(`P${rule.priority}`)
          .fontSize(11)
          .fontColor('#1D4ED8')
          .backgroundColor('#EFF6FF')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(8)
        Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
          .selectedColor('#2563EB')
          .onChange((isOn: boolean) => {
            this.toggleRule(rule, isOn);
          })
      }
      .width('100%')

      Text(`条件：${ConditionTextBuilder.toRuleText(rule.conditionGroup)}`)
        .fontSize(12)
        .fontColor('#475569')
        .width('100%')

      Text(`动作：${ConditionTextBuilder.actionsText(rule.actions, this.devices)}`)
        .fontSize(12)
        .fontColor('#475569')
        .width('100%')

      Row({ space: 8 }) {
        Text(rule.enabled ? '已启用' : '已停用')
          .fontSize(10)
          .fontColor(rule.enabled ? '#16A34A' : '#94A3B8')
        Text(rule.cooldownMs > 0 ? `冷却 ${Math.round(rule.cooldownMs / 1000)} s` : '无冷却')
          .fontSize(10)
          .fontColor('#94A3B8')
        Blank()
        Text('编辑 ›')
          .fontSize(11)
          .fontColor('#2563EB')
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .margin({ bottom: 10 })
    .onClick(() => {
      this.openEditor(rule.id);
    })
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(`共 ${this.rules.length} 条 · 启用 ${this.enabledCount()} 条`)
          .fontSize(12)
          .fontColor('#64748B')
          .layoutWeight(1)
        Text('+ 新建规则')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#2563EB')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .onClick(() => {
            this.openEditor('');
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14 })

      List({ space: 0 }) {
        if (this.conflictTip.length > 0) {
          ListItem() {
            Column({ space: 2 }) {
              Text('⚠ 冲突提示').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#B45309')
              Text(this.conflictTip).fontSize(11).fontColor('#B45309')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(10)
            .backgroundColor('#FFFBEB')
            .borderRadius(10)
            .border({ width: 1, color: '#F59E0B' })
            .margin({ bottom: 10 })
          }
        }
        ForEach(this.sorted(), (rule: AutomationRule) => {
          ListItem() {
            this.ruleCard(rule)
          }
        }, (rule: AutomationRule) => `${rule.id}-${rule.enabled}-${rule.updatedAt}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 14, right: 14 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 4 })
  }
}
