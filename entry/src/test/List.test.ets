import localUnitTest from './LocalUnit.test';
import ruleEngineTest from './RuleEngine.test';

export default function testsuite() {
  localUnitTest();
  ruleEngineTest();
}
