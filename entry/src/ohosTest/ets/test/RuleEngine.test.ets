import { describe, expect, it } from '@ohos/hypium';
import {
  AutomationRule, Device, EngineInput, EnvSnapshot, ExecutionPlan, RuleRuntimeState
} from '../../../main/ets/model/Types';
import { Defaults } from '../../../main/ets/model/Defaults';
import { DeviceReader } from '../../../main/ets/model/Readers';
import { RuleEngine } from '../../../main/ets/engine/RuleEngine';
import { RuleValidator, ValidationResult } from '../../../main/ets/engine/RuleValidator';
import { RuleRepository } from '../../../main/ets/store/RuleRepository';

/** 构造一次 tick 的输入，避免每条用例重复写样板 */
function makeInput(env: EnvSnapshot, rules: AutomationRule[], devices: Device[],
  runtime: Map<string, RuleRuntimeState>, now: number): EngineInput {
  return {
    env: env, devices: DeviceReader.cloneAll(devices), rules: rules,
    runtime: runtime, now: now
  };
}

function envOf(temperature: number, humidity: number, illuminance: number,
  noise: number): EnvSnapshot {
  return {
    temperature: temperature, humidity: humidity,
    illuminance: illuminance, noise: noise, updatedAt: 0
  };
}

export default function ruleEngineTest() {
  describe('RuleEngineTest', () => {
    // 1 正常：三条规则命中，顺序按优先级降序
    it('should_triggerThreeRules_inPriorityOrder', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(28.4, 66, 140, 42), rules, devices,
          new Map<string, RuleRuntimeState>(), 1000));
      expect(plan.steps.length).assertEqual(3);
      expect(plan.steps[0].ruleId).assertEqual('R-94');
      expect(plan.steps[1].ruleId).assertEqual('R-88');
      expect(plan.steps[2].ruleId).assertEqual('R-60');
      expect(plan.steps[0].seq).assertEqual(1);
    });

    // 2 正常：R-94 的目标亮度与当前值相同，因此不产生 brightness 写入动作
    it('should_skipIdempotentAction_whenValueAlreadySame', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      // 顶灯亮度初始就是 80，R-94 目标同为 80
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(28.4, 66, 140, 42), rules, devices,
          new Map<string, RuleRuntimeState>(), 1000));
      const step94 = plan.steps.filter((s) => s.ruleId === 'R-94')[0];
      let hasBrightness: boolean = false;
      for (let i = 0; i < step94.actions.length; i++) {
        if (step94.actions[i].property === 'brightness') {
          hasBrightness = true;
        }
      }
      expect(hasBrightness).assertFalse();
    });

    // 3 正常：两条规则争同一 targetKey，低优先级意图被记录为冲突
    it('should_recordConflict_when_twoRulesShareTarget', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(28.4, 66, 140, 42), rules, devices,
          new Map<string, RuleRuntimeState>(), 1000));
      expect(plan.conflicts.length > 0).assertTrue();
      const bulbConflict = plan.conflicts.filter((c) =>
        c.targetKey === 'd-light-ceiling.brightness');
      expect(bulbConflict.length).assertEqual(1);
      expect(bulbConflict[0].ruleId).assertEqual('R-60');
      expect(bulbConflict[0].keptBy).assertEqual('R-94');
      expect(bulbConflict[0].want).assertEqual(40);
    });

    // 4 边界：温度恰好等于阈值 28，>= 含等号
    it('should_trigger_whenTemperatureEqualsThreshold', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(28.0, 50, 900, 20), rules, devices,
          new Map<string, RuleRuntimeState>(), 1000));
      const ids: string[] = plan.steps.map((s) => s.ruleId);
      expect(ids.indexOf('R-88') >= 0).assertTrue();
    });

    // 5 边界：阈值下一档 27.99，不命中，返回空计划并留痕
    it('should_notTrigger_whenTemperatureBelowThreshold', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(27.99, 50, 300, 50), rules, devices,
          new Map<string, RuleRuntimeState>(), 1000));
      expect(plan.steps.length).assertEqual(0);
      expect(plan.records.length).assertEqual(1);
      expect(plan.records[0].matched).assertFalse();
    });

    // 6 边界：冷却窗口内只跳过、不执行
    it('should_skipRule_withinCooldownWindow', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const runtime: Map<string, RuleRuntimeState> = new Map<string, RuleRuntimeState>();
      runtime.set('R-94', { ruleId: 'R-94', lastTriggeredAt: 1000 });
      // R-94 冷却 60 s，10 s 后仍在窗口内
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(envOf(28.4, 66, 140, 42), rules, devices, runtime, 11000));
      const step94 = plan.steps.filter((s) => s.ruleId === 'R-94')[0];
      expect(step94.skipped).assertTrue();
      expect(step94.actions.length).assertEqual(0);
    });

    // 7 异常：环境值含 NaN，求值判为不满足，不抛异常
    it('should_notThrow_whenEnvValueIsNaN', 0, () => {
      const rules: AutomationRule[] = Defaults.rules();
      const devices: Device[] = Defaults.devices();
      const broken: EnvSnapshot = envOf(NaN, 66, 140, 42);
      const plan: ExecutionPlan = RuleEngine.evaluate(
        makeInput(broken, rules, devices, new Map<string, RuleRuntimeState>(), 1000));
      let r88: boolean = false;
      for (let i = 0; i < plan.steps.length; i++) {
        if (plan.steps[i].ruleId === 'R-88') {
          r88 = true;
        }
      }
      expect(r88).assertFalse();
      expect(plan.records.length > 0).assertTrue();
    });

    // 8 异常：条件组为空，校验拒绝保存
    it('should_rejectRule_withEmptyConditionList', 0, () => {
      const rules: AutomationRule[] = Defaults.rules().slice();
      const broken: AutomationRule = {
        id: 'R-00', name: '空规则', enabled: true, priority: 50,
        cooldownMs: 0, createdSeq: 99,
        conditionGroup: { logic: 'and', items: [] },
        actions: [{ deviceId: 'd-fan', property: 'power', value: 1 }],
        updatedAt: 0
      };
      const result: ValidationResult = RuleValidator.validate(broken, Defaults.devices());
      expect(result.ok).assertFalse();
      expect(result.codes.indexOf('EMPTY_CONDITION') >= 0).assertTrue();
    });

    // 9 异常：schemaVersion 不符，回落为 6 条默认规则
    it('should_fallbackToSeed_onSchemaVersionMismatch', 0, () => {
      const legacy: string = '{"schemaVersion":1,"rules":[]}';
      const rules: AutomationRule[] = RuleRepository.decodeRules(legacy);
      expect(rules.length).assertEqual(6);
      const broken: string = '{not a json';
      expect(RuleRepository.decodeRules(broken).length).assertEqual(6);
    });
  });
}
