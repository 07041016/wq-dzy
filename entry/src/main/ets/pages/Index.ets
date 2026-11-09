import { common } from '@kit.AbilityKit';
import { Boot } from '../viewmodel/Boot';
import { EnvPanelPage } from './EnvPanelPage';
import { RuleListPage } from './RuleListPage';
import { DevicePage } from './DevicePage';
import { LogPage } from './LogPage';

/**
 * 应用主界面：底部四个页签（环境 / 规则 / 设备 / 日志）。
 * 冷启动时先恢复数据，恢复完成前显示骨架屏，避免“先默认值后跳变”。
 */
@Entry
@Component
struct Index {
  @StorageProp('appReady') ready: boolean = false;
  @State currentTab: number = 0;
  private controller: TabsController = new TabsController();

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      Boot.start(ctx as common.UIAbilityContext);
    }
  }

  onBackPress(): boolean {
    Boot.flush();
    return false;
  }

  private tabName(): string {
    if (this.currentTab === 0) {
      return '环境';
    }
    if (this.currentTab === 1) {
      return '规则';
    }
    if (this.currentTab === 2) {
      return '设备';
    }
    return '日志';
  }

  @Builder
  tabItem(title: string, position: number) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(11)
        .fontColor(this.currentTab === position ? '#2563EB' : '#94A3B8')
        .fontWeight(this.currentTab === position ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  skeleton() {
    Column({ space: 12 }) {
      LoadingProgress().width(48).height(48).color('#2563EB')
      Text('正在恢复上次的规则与设备状态…')
        .fontSize(13)
        .fontColor('#64748B')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('栖舍 Qishe')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')
          Text('宿舍 A-302 · 智能联动实验室')
            .fontSize(11)
            .fontColor('#64748B')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.tabName())
          .fontSize(12)
          .fontColor('#2563EB')
          .backgroundColor('#EFF6FF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Column() {
        if (!this.ready) {
          this.skeleton()
        } else {
          Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.controller }) {
            TabContent() {
              EnvPanelPage()
            }.tabBar(this.tabItem('环境', 0))

            TabContent() {
              RuleListPage()
            }.tabBar(this.tabItem('规则', 1))

            TabContent() {
              DevicePage()
            }.tabBar(this.tabItem('设备', 2))

            TabContent() {
              LogPage()
            }.tabBar(this.tabItem('日志', 3))
          }
          .barHeight(56)
          .scrollable(false)
          .onChange((index: number) => {
            this.currentTab = index;
          })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FA')
  }
}

