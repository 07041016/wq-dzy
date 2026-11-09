import { UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheUi';

/**
 * 把可能抛异常的 UI 调用（Toast / 路由）收敛到一处：
 * 1. 用 UIContext 上的新接口，避开 promptAction.showToast、router.pushUrl 的废弃告警；
 * 2. 统一 try/catch，避免“Function may throw exceptions”告警。
 */
export class Ui {
  static toast(ui: UIContext, message: string): void {
    try {
      ui.getPromptAction().showToast({ message: message });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', message);
    }
  }

  static async pushRuleEditor(ui: UIContext, ruleId: string): Promise<void> {
    try {
      await ui.getRouter().pushUrl({
        url: 'pages/RuleEditPage',
        params: { 'ruleId': ruleId }
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'push failed: %{public}s', JSON.stringify(err));
    }
  }

  static async back(ui: UIContext): Promise<void> {
    try {
      await ui.getRouter().back();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'back failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 读取路由参数里的 ruleId，取不到返回空串 */
  static ruleIdParam(ui: UIContext): string {
    try {
      const params = ui.getRouter().getParams() as Record<string, string> | undefined;
      if (params === undefined) {
        return '';
      }
      const id: string = params['ruleId'];
      return id === undefined ? '' : id;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'getParams failed');
      return '';
    }
  }
}
