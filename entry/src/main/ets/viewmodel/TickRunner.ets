import { AutomationRule, Device, DeviceAction, EngineInput, EnvSnapshot, ExecutionPlan,
  ExecStep, RuleRuntimeState } from '../model/Types';
import { DeviceReader } from '../model/Readers';
import { RuleEngine } from '../engine/RuleEngine';
import { ConditionTextBuilder } from '../engine/ConditionTextBuilder';
import { RuleRepository } from '../store/RuleRepository';
import { LogRepository } from '../store/LogRepository';
import { EnvStore } from './EnvStore';
import { Keys } from '../model/Keys';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'QisheTick';

/**
 * 一次 tick 的执行入口：快照 → 引擎裁决 → 回写设备 → 落库 → 通知 UI。
 * 引擎本身是纯函数，这里只做“取数据 / 写数据 / 发事件”。
 */
export class TickRunner {
  private static runtime: Map<string, RuleRuntimeState> = new Map<string, RuleRuntimeState>();
  private static inflight: boolean = false;

  static busy(): boolean {
    return TickRunner.inflight;
  }

  static resetRuntime(): void {
    TickRunner.runtime = new Map<string, RuleRuntimeState>();
  }

  static async tick(): Promise<ExecutionPlan | undefined> {
    if (TickRunner.inflight) {
      hilog.info(DOMAIN, TAG, 'tick dropped: previous still running');
      return undefined;
    }
    TickRunner.inflight = true;
    try {
      const rules: AutomationRule[] = TickRunner.readRules();
      const devices: Device[] = TickRunner.readDevices();
      const env: EnvSnapshot = EnvStore.snapshot();
      const input: EngineInput = {
        env: env,
        devices: DeviceReader.cloneAll(devices),
        rules: rules,
        runtime: TickRunner.runtime,
        now: Date.now()
      };
      const plan: ExecutionPlan = RuleEngine.evaluate(input);
      const nextDevices: Device[] = TickRunner.applyPlan(plan, devices);
      TickRunner.markTriggered(plan, input.now);
      TickRunner.publish(plan, nextDevices);
      await RuleRepository.saveDevices(nextDevices);
      await LogRepository.append(plan.records);
      AppStorage.setOrCreate<number>(Keys.LOG_VERSION, Date.now());
      return plan;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'tick failed: %{public}s', JSON.stringify(err));
      return undefined;
    } finally {
      TickRunner.inflight = false;
    }
  }

  static readRules(): AutomationRule[] {
    const value: AutomationRule[] | undefined = AppStorage.get<AutomationRule[]>(Keys.RULES);
    return value === undefined ? [] : value;
  }

  static readDevices(): Device[] {
    const value: Device[] | undefined = AppStorage.get<Device[]>(Keys.DEVICES);
    return value === undefined ? [] : value;
  }

  /** 把计划中的动作写到设备副本上，返回新的数组（整体替换以触发刷新） */
  static applyPlan(plan: ExecutionPlan, devices: Device[]): Device[] {
    const next: Device[] = DeviceReader.cloneAll(devices);
    for (let i = 0; i < plan.steps.length; i++) {
      const step: ExecStep = plan.steps[i];
      if (step.skipped) {
        continue;
      }
      for (let j = 0; j < step.actions.length; j++) {
        const act: DeviceAction = step.actions[j];
        const dev: Device | undefined = DeviceReader.find(next, act.deviceId);
        if (dev === undefined) {
          continue;
        }
        DeviceReader.write(dev, act.property, act.value);
        dev.updatedAt = Date.now();
      }
    }
    return next;
  }

  static markTriggered(plan: ExecutionPlan, now: number): void {
    for (let i = 0; i < plan.steps.length; i++) {
      const step: ExecStep = plan.steps[i];
      if (step.skipped || step.actions.length === 0) {
        continue;
      }
      TickRunner.runtime.set(step.ruleId, { ruleId: step.ruleId, lastTriggeredAt: now });
    }
  }

  static publish(plan: ExecutionPlan, devices: Device[]): void {
    AppStorage.setOrCreate<Device[]>(Keys.DEVICES, devices);
    AppStorage.setOrCreate<string>(Keys.CONFLICT_TIP, TickRunner.tipOf(plan));
    AppStorage.setOrCreate<string>(Keys.LAST_PLAN, TickRunner.summaryOf(plan, devices));
  }

  /** 规则页顶部的橙色提示条文案 */
  static tipOf(plan: ExecutionPlan): string {
    if (plan.conflicts.length === 0) {
      return '';
    }
    const first = plan.conflicts[0];
    if (plan.conflicts.length === 1) {
      return `「${first.ruleName}」要求 ${first.targetKey} = ${first.want}，`
        + `已让位给优先级更高的 ${first.keptBy}`;
    }
    return `${plan.conflicts.length} 条规则的控制目标冲突，已按优先级依次执行`;
  }

  static summaryOf(plan: ExecutionPlan, devices: Device[]): string {
    const hit: number = plan.steps.filter((s: ExecStep) => !s.skipped).length;
    if (hit === 0) {
      return '本轮没有规则命中';
    }
    return `本轮命中 ${hit} 条规则 · ${plan.conflicts.length} 条冲突`;
  }

  static actionsText(step: ExecStep, devices: Device[]): string {
    return ConditionTextBuilder.actionsText(step.actions, devices);
  }
}


