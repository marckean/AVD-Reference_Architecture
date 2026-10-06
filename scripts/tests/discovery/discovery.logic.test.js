const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.resolve(__dirname, "..", "..", "..");
const data = JSON.parse(fs.readFileSync(path.join(repoRoot, "docs", "assets", "discovery", "questionnaire.json"), "utf8"));
const template = JSON.parse(fs.readFileSync(path.join(repoRoot, "deploy", "azuredeploy.json"), "utf8"));
const discovery = require(path.join(repoRoot, "docs", "assets", "javascripts", "discovery.js"));

function validateAgainstTemplate(parameters) {
  for (const [name, parameter] of Object.entries(parameters.parameters)) {
    const definition = template.parameters[name];
    assert.ok(definition, `Unexpected parameter emitted: ${name}`);
    assert.ok(Object.prototype.hasOwnProperty.call(parameter, "value"), `${name} must use ARM parameter value shape`);
    if (definition.allowedValues) {
      assert.ok(definition.allowedValues.includes(parameter.value), `${name} value ${parameter.value} is not allowed`);
    }
    if (definition.type === "bool") {
      assert.equal(typeof parameter.value, "boolean", `${name} must be boolean`);
    }
    if (definition.type === "int") {
      assert.equal(Number.isInteger(parameter.value), true, `${name} must be integer`);
    }
    if (definition.type === "array") {
      assert.equal(Array.isArray(parameter.value), true, `${name} must be array`);
    }
  }
}

test("questionnaire has required sections and question metadata", () => {
  assert.ok(data.sections.length >= 14);
  for (const section of data.sections) {
    assert.ok(section.id);
    assert.ok(section.title);
    assert.ok(section.questions.length > 0);
    for (const question of section.questions) {
      assert.ok(question.id);
      assert.equal(question.section, section.id);
      assert.ok(question.label);
      assert.ok(["single", "multiple", "yesno", "number", "text", "textarea"].includes(question.type));
      assert.ok(typeof question.why === "string" && question.why.length > 0);
      assert.ok(typeof question.whyHref === "string" && question.whyHref.length > 0);
      assert.ok(Object.prototype.hasOwnProperty.call(question, "default"));
      assert.ok(Object.prototype.hasOwnProperty.call(question, "required"));
    }
  }
});

test("conditional visibility follows showIf", () => {
  const defaults = discovery.makeDefaultAnswers(data);
  const subnet = data.sections.flatMap((section) => section.questions).find((question) => question.id === "existingSubnetResourceId");
  assert.equal(discovery.isQuestionVisible(subnet, defaults), false);
  defaults.useExistingHub = "yes";
  assert.equal(discovery.isQuestionVisible(subnet, defaults), true);
});

test("sizing estimates use expected formulas", () => {
  const answers = discovery.makeDefaultAnswers(data);
  answers.peakConcurrentUsers = 250;
  answers.sessionsPerHost = 10;
  answers.headroomPercent = 20;
  answers.profileStorageTier = "ssd-v2";
  const sizing = discovery.sizingEstimates(data, answers);
  assert.equal(sizing.sessionHosts.value, 30);
  assert.equal(sizing.fslogixSteady.value, 2500);
  assert.equal(sizing.fslogixSignIn.value, 12500);
  assert.equal(sizing.azureFilesShares.value, 1);
  assert.equal(sizing.appAttachSteady.value, 250);
  assert.equal(sizing.appAttachSignIn.value, 2500);
});

test("deployment parameters are valid ARM parameters and omit password", () => {
  const answers = discovery.makeDefaultAnswers(data);
  answers.orgShortCode = "contoso-avd";
  answers.primaryRegion = "australiaeast";
  answers.useExistingHub = "yes";
  answers.existingSubnetResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-contoso/providers/Microsoft.Network/virtualNetworks/vnet-contoso/subnets/snet-avd";
  const parameters = discovery.buildParameters(data, answers);
  assert.equal(parameters.$schema, "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#");
  assert.equal(parameters.parameters.workloadPrefix.value, "contoso-avd");
  assert.equal(parameters.parameters.location.value, "australiaeast");
  assert.equal(parameters.parameters.networkMode.value, "existing");
  assert.equal(parameters.parameters.sessionHostVmSize.value, "Standard_D8ads_v5");
  assert.equal(parameters.parameters.assignAutoscaleRolesToHostPoolIdentity.value, true);
  assert.equal(parameters.parameters.assignAutoscaleRolesToAvdServicePrincipal.value, false);
  assert.equal(parameters.parameters.hostPoolDeploymentScope.value, "Geographical");
  assert.equal(parameters.parameters.marketplaceImageOffer.value, "office-365");
  assert.equal(parameters.parameters.marketplaceImageSku.value, "win11-26h2-avd-m365");
  assert.ok(!parameters.parameters.marketplaceImageVersion);
  assert.ok(!parameters.parameters.localAdminPassword);
  assert.ok(!parameters.parameters.enableSubscriptionRoleAssignments);
  validateAgainstTemplate(parameters);
  assert.doesNotThrow(() => JSON.parse(JSON.stringify(parameters)));
});

test("deployment parameters match template allowed values across answer sets", () => {
  const scenarios = [
    {},
    {
      includeM365Apps: "no",
      sessionHostVmSize: "Standard_D4ads_v5",
      hostPoolDeploymentScope: "Regional",
      avdServicePrincipalAutoscaleRoles: "no",
      assignAutoscaleRolesToHostPoolIdentity: "no"
    },
    {
      includeM365Apps: "yes",
      sessionHostVmSize: "Standard_E8ads_v5",
      hostPoolDeploymentScope: "Geographical",
      avdServicePrincipalAutoscaleRoles: "yes"
    },
    {
      sessionHostVmSize: "Standard_D8s_v5"
    }
  ];

  for (const scenario of scenarios) {
    const answers = Object.assign(discovery.makeDefaultAnswers(data), scenario);
    const parameters = discovery.buildParameters(data, answers);
    validateAgainstTemplate(parameters);
  }

  const noM365 = discovery.buildParameters(data, Object.assign(discovery.makeDefaultAnswers(data), { includeM365Apps: "no" }));
  assert.equal(noM365.parameters.marketplaceImageOffer.value, "Windows-11");
  assert.equal(noM365.parameters.marketplaceImageSku.value, "win11-26h2-avd");

  const absentServicePrincipalRoles = discovery.buildParameters(data, Object.assign(discovery.makeDefaultAnswers(data), { avdServicePrincipalAutoscaleRoles: "no" }));
  assert.equal(absentServicePrincipalRoles.parameters.assignAutoscaleRolesToAvdServicePrincipal.value, true);

  const invalidSize = discovery.buildParameters(data, Object.assign(discovery.makeDefaultAnswers(data), { sessionHostVmSize: "Standard_D8s_v5" }));
  assert.equal(invalidSize.parameters.sessionHostVmSize.value, "Standard_D8ads_v5");
});

test("blank marketplace image version omits parameter and emits lookup commands", () => {
  const answers = Object.assign(discovery.makeDefaultAnswers(data), {
    primaryRegion: "australiaeast",
    includeM365Apps: "yes",
    marketplaceImageVersion: ""
  });
  const parameters = discovery.buildParameters(data, answers);
  const commands = discovery.buildDeploymentCommands(data, answers, parameters);
  const report = discovery.makeMarkdownReport(data, answers, discovery.computeResults(data, answers));
  assert.ok(!parameters.parameters.marketplaceImageVersion);
  assert.match(commands.cli, /version=\$\(az vm image list -l australiaeast -p MicrosoftWindowsDesktop -f office-365 -s win11-26h2-avd-m365 --all --query "\[-1\]\.version" -o tsv\)/);
  assert.match(commands.cli, /--parameters marketplaceImageVersion=\$version/);
  assert.match(commands.powerShell, /Get-AzVMImage -Location australiaeast -PublisherName MicrosoftWindowsDesktop -Offer office-365 -Skus win11-26h2-avd-m365/);
  assert.match(commands.powerShell, /-marketplaceImageVersion \$version/);
  assert.match(report, /Marketplace image version/);
});

test("exact marketplace image version is passed through and skips lookup", () => {
  const answers = Object.assign(discovery.makeDefaultAnswers(data), {
    marketplaceImageVersion: "26300.9457.260914"
  });
  const parameters = discovery.buildParameters(data, answers);
  const commands = discovery.buildDeploymentCommands(data, answers, parameters);
  assert.equal(parameters.parameters.marketplaceImageVersion.value, "26300.9457.260914");
  assert.doesNotMatch(commands.cli, /az vm image list/);
  assert.doesNotMatch(commands.powerShell, /Get-AzVMImage/);
  validateAgainstTemplate(parameters);
});

test("latest marketplace image version is rejected", () => {
  const answers = Object.assign(discovery.makeDefaultAnswers(data), {
    marketplaceImageVersion: "latest"
  });
  const parameters = discovery.buildParameters(data, answers);
  const commands = discovery.buildDeploymentCommands(data, answers, parameters);
  assert.ok(!parameters.parameters.marketplaceImageVersion);
  assert.match(commands.cli, /az vm image list/);
});

test("answer export and import round trip preserves values", () => {
  const answers = discovery.makeDefaultAnswers(data);
  answers.orgName = "Contoso";
  answers.peakConcurrentUsers = 321;
  const exported = JSON.stringify({ version: data.version, answers });
  const imported = JSON.parse(exported);
  assert.equal(imported.answers.orgName, "Contoso");
  assert.equal(imported.answers.peakConcurrentUsers, 321);
});

test("patterns and readiness react to legacy answers", () => {
  const answers = discovery.makeDefaultAnswers(data);
  answers.legacyMachineAuth = "yes";
  answers.ntlmDependency = "ntlmv1";
  const results = discovery.computeResults(data, answers);
  assert.ok(results.patterns.some((pattern) => pattern.id === "twoHostPools"));
  const machineAuth = results.dependencies.find((dependency) => dependency.id === "machineAuth");
  const ntlm = results.dependencies.find((dependency) => dependency.id === "ntlm");
  assert.equal(machineAuth.status, "needed");
  assert.equal(ntlm.status, "needed");
});
