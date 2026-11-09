import { Fmt } from '../model/Readers';

/**
 * 一路环境量：标签 + 数值 + 滑块。
 * 必须做成 @Component + @Prop，才能让父组件状态变化时刷新数值；
 * @Builder 的按值传参不会随状态更新，拖动后数字会停在旧值。
 */
@Component
export struct EnvSliderRow {
  @Prop label: string = '';
  @Prop unit: string = '';
  @Prop value: number = 0;
  @Prop minValue: number = 0;
  @Prop maxValue: number = 100;
  @Prop stepValue: number = 1;
  @Prop digits: number = 0;
  onValue: (v: number) => void = (v: number) => {
  };

  build() {
    Column({ space: 2 }) {
      Row() {
        Text(this.label)
          .fontSize(13)
          .fontColor('#475569')
          .width(52)
        Text(`${Fmt.num(this.value, this.digits)} ${this.unit}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F172A')
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Slider({
        value: this.value,
        min: this.minValue,
        max: this.maxValue,
        step: this.stepValue,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor('#2563EB')
        .trackColor('#E2E8F0')
        .onChange((changed: number, mode: SliderChangeMode) => {
          this.onValue(changed);
        })
    }
    .width('100%')
    .padding({ top: 5, bottom: 5 })
  }
}
