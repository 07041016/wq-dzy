import { Device, ExecutionRecord } from '../model/Types';
import { Defaults } from '../model/Defaults';
import { Fmt } from '../model/Readers';
import { ConditionTextBuilder } from '../engine/ConditionTextBuilder';
import { LogRepository } from '../store/LogRepository';
import { Ui } from '../common/Ui';

/**
 * 执行日志：从 RDB 按 ts 倒序分页读取，最多展示最近 100 条。
 * “顺序 N”就是策略里的 seq，冲突与跳过都会留痕。
 */
@Component
export struct LogPage {
  @StorageProp('logVersion') @Watch('onLogChanged') logVersion: number = 0;
  @StorageProp('deviceList') devices: Device[] = Defaults.devices();
  @State logs: ExecutionRecord[] = [];
  @State total: number = 0;
  @State loading: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  onLogChanged(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const rows: ExecutionRecord[] = await LogRepository.queryPage(0, 100);
      this.logs = rows;
      this.total = await LogRepository.count();
    } finally {
      this.loading = false;
    }
  }

  private async clearAll(): Promise<void> {
    await LogRepository.clear();
    this.logs = [];
    this.total = 0;
    Ui.toast(this.getUIContext(), '日志已清空');
  }

  private tagText(row: ExecutionRecord): string {
    if (row.skipped) {
      return '跳过';
    }
    if (row.conflicts.length > 0) {
      return '冲突';
    }
    if (!row.matched) {
      return '未命中';
    }
    return `顺序 ${row.seq}`;
  }

  private tagColor(row: ExecutionRecord): string {
    if (row.skipped) {
      return '#64748B';
    }
    if (row.conflicts.length > 0) {
      return '#B91C1C';
    }
    if (!row.matched) {
      return '#94A3B8';
    }
    return '#1D4ED8';
  }

  private resultText(row: ExecutionRecord): string {
    if (row.skipped) {
      return '冷却窗口内跳过，未改动设备';
    }
    if (!row.matched) {
      return '本轮没有规则命中';
    }
    if (row.actions.length === 0) {
      return '动作与当前值相同，幂等跳过';
    }
    return ConditionTextBuilder.actionsText(row.actions, this.devices);
  }

  @Builder
  logRow(row: ExecutionRecord) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(Fmt.time(row.ts))
          .fontSize(11)
          .fontColor('#94A3B8')
        Text(this.tagText(row))
          .fontSize(10)
          .fontColor(Color.White)
          .backgroundColor(this.tagColor(row))
          .padding({ left: 8, right: 8, top: 1, bottom: 1 })
          .borderRadius(7)
        Text(row.ruleName)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
      }
      .width('100%')

      Text(`条件：${row.conditionText}`)
        .fontSize(11)
        .fontColor('#475569')
        .width('100%')

      Text(`结果：${this.resultText(row)}`)
        .fontSize(11)
        .fontColor(row.conflicts.length > 0 ? '#B45309' : '#475569')
        .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(`今日 ${this.total} 条 · 保留最近 500 条`)
          .fontSize(12)
          .fontColor('#64748B')
          .layoutWeight(1)
        Text('清空')
          .fontSize(12)
          .fontColor('#B91C1C')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#FEF2F2')
          .borderRadius(10)
          .onClick(() => {
            this.clearAll();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14 })

      List({ space: 0 }) {
        ForEach(this.logs, (row: ExecutionRecord) => {
          ListItem() {
            this.logRow(row)
          }
        }, (row: ExecutionRecord) => `${row.id}-${row.ts}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 14, right: 14 })
      .scrollBar(BarState.Off)
      .onReachEnd(() => {
        this.reload();
      })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 4 })
  }
}
