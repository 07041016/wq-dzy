/** 数值输入行：规则编辑器里的阈值、动作目标值都用它。 */
@Component
export struct NumberField {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  onValue: (v: string) => void = (v: string) => {
  };

  build() {
    Row() {
      Text(this.label)
        .fontSize(11)
        .fontColor('#94A3B8')
        .width(64)
      TextInput({ text: this.value, placeholder: '0' })
        .type(InputType.Number)
        .fontSize(13)
        .height(34)
        .layoutWeight(1)
        .backgroundColor('#F7F9FC')
        .onChange((v: string) => {
          this.onValue(v);
        })
      if (this.unit.length > 0) {
        Text(this.unit)
          .fontSize(11)
          .fontColor('#94A3B8')
          .width(28)
          .textAlign(TextAlign.End)
      }
    }
    .width('100%')
    .margin({ top: 4 })
  }
}

