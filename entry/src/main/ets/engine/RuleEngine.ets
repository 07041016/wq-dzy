import {
  AutomationRule, EngineInput, ExecutionPlan, ExecutionRecord, ExecStep, ResolveResult
} from '../model/Types';
import { ConditionEvaluator } from './ConditionEvaluator';
import { ConditionTextBuilder } from './ConditionTextBuilder';
import { ConflictResolver } from './ConflictResolver';

/**
 * 规则引擎：纯函数，不读存储、不碰 UI、不抛异常。
 * 同样的 EngineInput 必然得到同样的 ExecutionPlan，便于单测直接断言。
 */
export class RuleEngine {
  static evaluate(input: EngineInput): ExecutionPlan {
    const matched: AutomationRule[] = [];
    for (let i = 0; i < input.rules.length; i++) {
      const rule: AutomationRule = input.rules[i];
      if (!rule.enabled) {
        continue;
      }
      if (ConditionEvaluator.evalGroup(rule.conditionGroup, input.env, input.devices)) {
        matched.push(rule);
      }
    }

    if (matched.length === 0) {
      return RuleEngine.emptyPlan(input);
    }

    const ordered: AutomationRule[] = ConflictResolver.sortByPriority(matched);
    const resolved: ResolveResult =
      ConflictResolver.resolve(ordered, input.devices, input.runtime, input.now);

    const steps: ExecStep[] = [];
    for (let i = 0; i < resolved.steps.length; i++) {
      const r = resolved.steps[i];
      steps.push({
        seq: i + 1,
        ruleId: r.rule.id,
        ruleName: r.rule.name,
        priority: r.rule.priority,
        conditionText: ConditionTextBuilder.toLogText(
          r.rule.conditionGroup, input.env, input.devices),
        actions: r.actions,
        skipped: r.skipped,
        cooldownRemainMs: r.cooldownRemainMs
      });
    }

    const records: ExecutionRecord[] =
      RuleEngine.toRecords(steps, resolved, input.now);
    return { steps: steps, conflicts: resolved.conflicts, records: records };
  }

  /** 把每个 step 转成一条执行记录（含冲突归属与跳过标记） */
  static toRecords(steps: ExecStep[], resolved: ResolveResult, now: number): ExecutionRecord[] {
    const records: ExecutionRecord[] = [];
    for (let i = 0; i < steps.length; i++) {
      const step: ExecStep = steps[i];
      const related = resolved.conflicts.filter((c) => c.ruleId === step.ruleId);
      records.push({
        id: 0,
        ts: now,
        seq: step.seq,
        ruleId: step.ruleId,
        ruleName: step.ruleName,
        conditionText: step.conditionText,
        matched: !step.skipped,
        actions: step.actions,
        conflicts: related,
        skipped: step.skipped
      });
    }
    return records;
  }

  /** 边界：一条规则都没命中，也要留一条 matched=false 的记录 */
  static emptyPlan(input: EngineInput): ExecutionPlan {
    const record: ExecutionRecord = {
      id: 0,
      ts: input.now,
      seq: 0,
      ruleId: '',
      ruleName: '（无规则命中）',
      conditionText: `温度 ${input.env.temperature} ℃ / 湿度 ${input.env.humidity} % / `
        + `光照 ${input.env.illuminance} lx / 噪声 ${input.env.noise} dB`,
      matched: false,
      actions: [],
      conflicts: [],
      skipped: false
    };
    return { steps: [], conflicts: [], records: [record] };
  }
}

