(function () {
  "use strict";

  const ROOT_SELECTOR = "[data-discovery-questionnaire]";
  const DEFAULT_DATA_URL = "assets/discovery/questionnaire.json";
  let siteRootUrl = null;

  // Links in questionnaire.json are written relative to the site root, optionally with leading "../".
  // MkDocs serves this page at /accelerators/discovery-questionnaire/, so they are resolved against the
  // site root rather than the page. Material for MkDocs exposes the site root as __md_scope.
  function findSiteRoot(rootElement) {
    if (typeof window !== "undefined" && window.__md_scope instanceof URL) {
      return window.__md_scope;
    }
    const hint = rootElement && rootElement.getAttribute("data-site-root");
    return new URL(hint || "../../", window.location.href);
  }

  function siteUrl(href) {
    if (!href || !siteRootUrl || /^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith("#") || href.startsWith("/")) {
      return href;
    }
    return new URL(href.replace(/^(\.\.\/)+/, ""), siteRootUrl).href;
  }

  function asArray(value) {
    return Array.isArray(value) ? value : [];
  }

  function toNumber(value, fallback) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function slug(value) {
    return String(value || "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "");
  }

  function makeDefaultAnswers(data) {
    const answers = {};
    asArray(data.sections).forEach((section) => {
      asArray(section.questions).forEach((question) => {
        if (Array.isArray(question.default)) {
          answers[question.id] = question.default.slice();
        } else if (question.default !== undefined) {
          answers[question.id] = question.default;
        } else if (question.type === "multiple") {
          answers[question.id] = [];
        } else {
          answers[question.id] = "";
        }
      });
    });
    return answers;
  }

  function getQuestion(data, id) {
    for (const section of asArray(data.sections)) {
      for (const question of asArray(section.questions)) {
        if (question.id === id) {
          return question;
        }
      }
    }
    return null;
  }

  function getAnswer(answers, id, fallback) {
    const value = answers[id];
    if (value === undefined || value === null || value === "") {
      return fallback;
    }
    return value;
  }

  function isExactMarketplaceImageVersion(value) {
    return /^\d+\.\d+\.\d+$/.test(String(value || ""));
  }

  function getImageSelection(answers) {
    const includeM365Apps = answers.includeM365Apps !== "no";
    return {
      location: getAnswer(answers, "primaryRegion", "<location>"),
      publisher: "MicrosoftWindowsDesktop",
      offer: includeM365Apps ? "office-365" : "Windows-11",
      sku: includeM365Apps ? "win11-26h2-avd-m365" : "win11-26h2-avd",
      version: getAnswer(answers, "marketplaceImageVersion", "")
    };
  }

  function getValidationMessage(question, value) {
    if (!question.validation || value === undefined || value === null || value === "") {
      return "";
    }
    if (question.validation.pattern && !(new RegExp(question.validation.pattern).test(String(value)))) {
      return question.validation.invalidMessage || "Enter a valid value.";
    }
    return "";
  }

  function matchesCondition(answers, condition) {
    if (!condition) {
      return true;
    }
    const value = answers[condition.answerId];
    if (Object.prototype.hasOwnProperty.call(condition, "equals")) {
      return value === condition.equals;
    }
    if (Object.prototype.hasOwnProperty.call(condition, "notEquals")) {
      return value !== condition.notEquals;
    }
    if (Object.prototype.hasOwnProperty.call(condition, "includes")) {
      return Array.isArray(value) && value.includes(condition.includes);
    }
    return true;
  }

  function isQuestionVisible(question, answers) {
    return matchesCondition(answers, question.showIf);
  }

  function triggerMatches(trigger, answers) {
    const value = answers[trigger.answerId];
    switch (trigger.operator) {
      case "equals":
        return value === trigger.value;
      case "notEquals":
        return value !== trigger.value;
      case "in":
        return asArray(trigger.value).includes(value);
      case "includes":
        return Array.isArray(value) && value.includes(trigger.value);
      case "lessThanOrEqual":
        return toNumber(value, Number.POSITIVE_INFINITY) <= Number(trigger.value);
      case "greaterThan":
        return toNumber(value, Number.NEGATIVE_INFINITY) > Number(trigger.value);
      default:
        return false;
    }
  }

  function recommendedPatterns(data, answers) {
    return asArray(data.patterns)
      .filter((pattern) => asArray(pattern.triggers).some((trigger) => triggerMatches(trigger, answers)))
      .map((pattern) => ({
        id: pattern.id,
        label: pattern.label,
        siteHref: pattern.siteHref,
        reason: pattern.reason
      }));
  }

  function dependencyReadiness(data, answers) {
    return asArray(data.dependencies).map((dependency) => {
      const value = answers[dependency.answerId];
      const ready = asArray(dependency.readyValues).includes(value);
      return {
        id: dependency.id,
        label: dependency.label,
        siteHref: dependency.siteHref,
        status: ready ? "in place" : "needed",
        answer: value
      };
    });
  }

  function decisionsForAnswers(data, answers) {
    const desktopDelivery = getAnswer(answers, "desktopDelivery", "full-desktop");
    const persistent = answers.persistentDesktops === "yes" || answers.developerDesktops === "yes";
    const legacy = answers.legacyMachineAuth === "yes" || ["ntlmv1", "unknown"].includes(answers.ntlmDependency);
    const sessionHostConfig = answers.sessionHostConfigReady === "yes";
    const deploymentScope = getAnswer(answers, "hostPoolDeploymentScope", "Geographical");

    return [
      {
        label: "Host pool type",
        value: persistent
          ? "Use pooled host pools for shared users and a separate personal-desktop pattern for dedicated users."
          : desktopDelivery === "remoteapp-only"
            ? "Use a pooled host pool with RemoteApp application groups."
            : "Use a pooled host pool with a desktop application group.",
        source: data.learnSources.hostPoolManagement
      },
      {
        label: "Management approach",
        value: sessionHostConfig
          ? "Create the North Star pool with a session host configuration from day one."
          : "Treat this as a standard-management stepping stone. A session host configuration cannot be added later.",
        source: data.learnSources.hostPoolManagement
      },
      {
        label: "Join type per pool",
        value: legacy
          ? "Use a Microsoft Entra joined North Star pool and a separate hybrid-joined legacy pool for exceptions."
          : "Use Microsoft Entra joined session hosts for the pooled North Star host pool.",
        source: data.learnSources.entraJoinedHosts
      },
      {
        label: "Host pool metadata scope",
        value: deploymentScope === "Regional"
          ? "Regional was explicitly selected. Confirm the target Azure region supports Regional host pools before deployment."
          : "Use the default Geographical deployment scope unless there is a supported-region requirement for Regional.",
        source: data.learnSources.regionalHostPools
      }
    ];
  }

  function sizingEstimates(data, answers) {
    const assumptions = data.sizingAssumptions || {};
    const peak = Math.max(0, toNumber(answers.peakConcurrentUsers, 0));
    const sessionsPerHost = Math.max(1, toNumber(answers.sessionsPerHost, 1));
    const headroom = Math.max(0, toNumber(answers.headroomPercent, 0));
    const baseHosts = Math.ceil(peak / sessionsPerHost);
    const hostsWithHeadroom = Math.ceil(baseHosts * (1 + headroom / 100));
    const fsSteady = peak * assumptions.fslogixSteadyIopsPerUser;
    const fsSignIn = peak * assumptions.fslogixSignInIopsPerUser;
    const profileTier = answers.profileStorageTier || "ssd-v2";
    const maxIops = profileTier === "hdd-v2"
      ? assumptions.azureFilesHddProvisionedV2MaxIops
      : assumptions.azureFilesSsdProvisionedV2MaxIops;
    const sharesForSteady = Math.max(1, Math.ceil(fsSteady / maxIops));
    const sharesForSignIn = Math.max(1, Math.ceil(fsSignIn / maxIops));
    const appSteady = peak * assumptions.appAttachSteadyIopsPerUser;
    const appSignIn = peak * assumptions.appAttachBootSignInIopsPerUser;

    return {
      sessionHosts: {
        label: "Estimated session hosts needed",
        value: hostsWithHeadroom,
        formula: `ceil(ceil(${peak} peak concurrent users / ${sessionsPerHost} sessions per host) * (1 + ${headroom}% headroom))`,
        source: "../host-pools/sizing-and-load-balancing/"
      },
      fslogixSteady: {
        label: "Estimated FSLogix steady-state IOPS",
        value: fsSteady,
        formula: `${peak} users * ${assumptions.fslogixSteadyIopsPerUser} steady-state IOPS per user`,
        source: data.learnSources.fslogixStorage
      },
      fslogixSignIn: {
        label: "Estimated FSLogix sign-in IOPS",
        value: fsSignIn,
        formula: `${peak} users * ${assumptions.fslogixSignInIopsPerUser} sign-in IOPS per user`,
        source: data.learnSources.fslogixStorage
      },
      azureFilesShares: {
        label: "Estimated Azure Files shares or storage accounts",
        value: Math.max(sharesForSteady, sharesForSignIn),
        formula: `ceil(required IOPS / ${maxIops} IOPS per ${profileTier === "hdd-v2" ? "HDD provisioned v2" : "SSD provisioned v2"} share or storage account)`,
        source: `${data.learnSources.azureFilesScale} and ${data.learnSources.azureFilesBilling}`
      },
      appAttachSteady: {
        label: "Estimated App Attach steady-state share IOPS",
        value: appSteady,
        formula: `${peak} users * ${assumptions.appAttachSteadyIopsPerUser} steady-state IOPS per user`,
        source: data.learnSources.appAttach
      },
      appAttachSignIn: {
        label: "Estimated App Attach boot or sign-in share IOPS",
        value: appSignIn,
        formula: `${peak} users * ${assumptions.appAttachBootSignInIopsPerUser} boot or sign-in IOPS per user`,
        source: data.learnSources.appAttach
      }
    };
  }

  function valueFromMap(entry, answers) {
    if (!entry) {
      return undefined;
    }
    if (entry.type === "constant") {
      return entry.value;
    }
    if (entry.type === "answer") {
      const value = getAnswer(answers, entry.answerId, entry.fallback);
      if (entry.omitWhenBlank && (value === undefined || value === null || value === "")) {
        return undefined;
      }
      if (entry.pattern && !(new RegExp(entry.pattern).test(String(value)))) {
        return undefined;
      }
      if (typeof entry.fallback === "number") {
        return toNumber(value, entry.fallback);
      }
      if (typeof entry.fallback === "boolean") {
        return value === true || value === "yes";
      }
      if (Array.isArray(entry.allowedValues) && !entry.allowedValues.includes(value)) {
        return entry.fallback;
      }
      return value;
    }
    if (entry.type === "conditional") {
      return answers[entry.answerId] === entry.equals ? entry.trueValue : entry.falseValue;
    }
    if (entry.type === "tags") {
      const tags = {};
      Object.entries(entry.values || {}).forEach(([key, value]) => {
        if (value && typeof value === "object" && value.answerId) {
          tags[key] = getAnswer(answers, value.answerId, value.fallback);
        } else {
          tags[key] = value;
        }
      });
      return tags;
    }
    return undefined;
  }

  function buildParameters(data, answers) {
    const map = data.parameterMap || {};
    const omit = new Set(asArray(map.omitParameters));
    const parameters = {};
    Object.entries(map.parameters || {}).forEach(([name, entry]) => {
      if (omit.has(name)) {
        return;
      }
      const value = valueFromMap(entry, answers);
      if (value !== undefined) {
        parameters[name] = { value };
      }
    });
    return {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
      contentVersion: "1.0.0.0",
      parameters
    };
  }

  function computeResults(data, answers) {
    return {
      patterns: recommendedPatterns(data, answers),
      decisions: decisionsForAnswers(data, answers),
      dependencies: dependencyReadiness(data, answers),
      sizing: sizingEstimates(data, answers),
      parameters: buildParameters(data, answers)
    };
  }

  function makeMarkdownReport(data, answers, results) {
    const lines = [];
    lines.push(`# ${data.title}`);
    lines.push("");
    lines.push("## Answers");
    asArray(data.sections).forEach((section) => {
      lines.push("");
      lines.push(`### ${section.title}`);
      asArray(section.questions).forEach((question) => {
        if (!isQuestionVisible(question, answers)) {
          return;
        }
        const value = answers[question.id];
        const formatted = Array.isArray(value) ? value.join(", ") : String(value ?? "");
        lines.push(`- **${question.label}:** ${formatted || "Not answered"}`);
      });
    });
    lines.push("");
    lines.push("## Recommended patterns");
    results.patterns.forEach((pattern) => lines.push(`- **${pattern.label}:** ${pattern.reason}`));
    lines.push("");
    lines.push("## Decisions fixed at host pool creation");
    results.decisions.forEach((decision) => lines.push(`- **${decision.label}:** ${decision.value}`));
    lines.push("");
    lines.push("## Dependency readiness");
    results.dependencies.forEach((dependency) => lines.push(`- **${dependency.label}:** ${dependency.status}`));
    lines.push("");
    lines.push("## Sizing estimates");
    Object.values(results.sizing).forEach((item) => lines.push(`- **${item.label}:** ${item.value}. Formula: ${item.formula}. Source: ${item.source}`));
    lines.push("");
    lines.push("## Deployment parameters");
    lines.push("The generated azuredeploy.parameters.json omits localAdminPassword. Supply the password securely at deployment time.");
    if (!results.parameters.parameters.marketplaceImageVersion) {
      const commands = buildDeploymentCommands(data, answers, results.parameters);
      lines.push("");
      lines.push("## Open items");
      lines.push("- **Marketplace image version:** exact version not supplied. Look it up before deployment.");
      lines.push(`  - Azure CLI: ${commands.versionLookup.cliOneLine}`);
      lines.push(`  - Azure PowerShell: ${commands.versionLookup.powerShellOneLine}`);
    }
    return lines.join("\n");
  }

  function el(tag, options, children) {
    const element = document.createElement(tag);
    const opts = options || {};
    Object.entries(opts).forEach(([key, value]) => {
      if (key === "className") {
        element.className = value;
      } else if (key === "text") {
        element.textContent = value;
      } else if (key === "html") {
        element.innerHTML = value;
      } else if (key.startsWith("data")) {
        element.dataset[key.substring(4).replace(/^[A-Z]/, (char) => char.toLowerCase())] = value;
      } else if (key === "for") {
        element.htmlFor = value;
      } else {
        element.setAttribute(key, value);
      }
    });
    asArray(children).forEach((child) => {
      if (child === null || child === undefined) {
        return;
      }
      element.appendChild(typeof child === "string" ? document.createTextNode(child) : child);
    });
    return element;
  }

  function renderQuestion(question, answers, onChange) {
    const wrapper = el("div", { className: "dq-question", id: `dq-question-${question.id}` });
    const labelId = `dq-label-${question.id}`;
    const hintId = `dq-hint-${question.id}`;
    const inputName = `dq-${question.id}`;

    function setValue(value, mode) {
      answers[question.id] = value;
      onChange(mode || "render");
    }

    if (["single", "multiple", "yesno"].includes(question.type)) {
      const fieldset = el("fieldset", { "aria-labelledby": labelId, "aria-describedby": hintId });
      fieldset.appendChild(el("legend", { id: labelId, text: question.label }));
      const options = question.type === "yesno"
        ? [{ value: "yes", label: "Yes" }, { value: "no", label: "No" }]
        : asArray(question.options);
      options.forEach((option) => {
        const id = `${inputName}-${slug(option.value)}`;
        const input = el("input", {
          type: question.type === "multiple" ? "checkbox" : "radio",
          id,
          name: inputName,
          value: option.value
        });
        if (question.type === "multiple") {
          input.checked = asArray(answers[question.id]).includes(option.value);
          input.addEventListener("change", () => {
            const current = new Set(asArray(answers[question.id]));
            if (input.checked) {
              current.add(option.value);
            } else {
              current.delete(option.value);
            }
            setValue(Array.from(current));
          });
        } else {
          input.checked = answers[question.id] === option.value;
          input.addEventListener("change", () => {
            if (input.checked) {
              setValue(option.value);
            }
          });
        }
        fieldset.appendChild(el("label", { className: "dq-option", for: id }, [
          input,
          el("span", { text: option.label })
        ]));
      });
      wrapper.appendChild(fieldset);
    } else {
      const inputId = `dq-input-${question.id}`;
      wrapper.appendChild(el("label", { id: labelId, for: inputId, text: question.label }));
      const input = question.type === "textarea"
        ? el("textarea", { id: inputId, name: inputName, rows: "4", "aria-describedby": hintId })
        : el("input", { id: inputId, name: inputName, type: question.type === "number" ? "number" : "text", "aria-describedby": hintId });
      input.value = answers[question.id] ?? "";
      const validationId = `dq-validation-${question.id}`;
      if (question.validation) {
        input.setAttribute("aria-describedby", `${hintId} ${validationId}`);
        if (question.validation.pattern) {
          input.setAttribute("pattern", question.validation.pattern);
        }
      }
      let validationElement = null;
      function refreshValidation(value) {
        if (!question.validation) {
          return;
        }
        const message = getValidationMessage(question, value);
        input.setCustomValidity(message);
        if (validationElement) {
          validationElement.textContent = message;
        }
      }
      input.addEventListener("input", () => {
        const value = question.type === "number" ? toNumber(input.value, 0) : input.value;
        refreshValidation(value);
        setValue(value, "results");
      });
      input.addEventListener("change", () => {
        setValue(question.type === "number" ? toNumber(input.value, 0) : input.value, "render");
      });
      wrapper.appendChild(input);
      if (question.validation) {
        const message = getValidationMessage(question, answers[question.id]);
        validationElement = el("p", {
          className: "dq-validation",
          id: validationId,
          text: message
        });
        input.setCustomValidity(message);
        wrapper.appendChild(validationElement);
      }
    }

    const why = el("p", { className: "dq-why", id: hintId }, [
      el("strong", { text: "Why we ask: " }),
      document.createTextNode(question.why || ""),
      question.whyHref ? document.createTextNode(" ") : null,
      question.whyHref ? el("a", { href: siteUrl(question.whyHref), target: question.whyHref.startsWith("http") ? "_blank" : "", rel: "noopener", text: "Read more" }) : null
    ]);
    wrapper.appendChild(why);
    if (question.required) {
      wrapper.appendChild(el("span", { className: "dq-required", text: "Required" }));
    }
    return wrapper;
  }

  function renderForm(data, answers, state, onChange) {
    const form = el("form", { className: "dq-form" });
    asArray(data.sections).forEach((section, index) => {
      const sectionElement = el("section", {
        className: `dq-section ${index === state.activeSection ? "is-active" : ""}`,
        id: `dq-section-${section.id}`,
        "aria-labelledby": `dq-section-title-${section.id}`
      });
      sectionElement.appendChild(el("h2", { id: `dq-section-title-${section.id}`, text: section.title }));
      asArray(section.questions).forEach((question) => {
        const questionElement = renderQuestion(question, answers, onChange);
        questionElement.hidden = !isQuestionVisible(question, answers);
        sectionElement.appendChild(questionElement);
      });
      form.appendChild(sectionElement);
    });
    return form;
  }

  function renderSectionNav(data, answers, state, root, update) {
    const nav = el("nav", { className: "dq-tabs", "aria-label": "Questionnaire sections" });
    asArray(data.sections).forEach((section, index) => {
      const total = asArray(section.questions).filter((question) => isQuestionVisible(question, answers)).length;
      const button = el("button", {
        type: "button",
        className: index === state.activeSection ? "is-active" : "",
        "aria-current": index === state.activeSection ? "step" : "false"
      }, [
        el("span", { text: section.title }),
        el("small", { text: `${total} questions` })
      ]);
      button.addEventListener("click", () => {
        state.activeSection = index;
        update();
        root.querySelector(".dq-shell")?.scrollIntoView({ block: "start" });
      });
      nav.appendChild(button);
    });
    return nav;
  }

  function renderList(items, emptyText) {
    if (!items.length) {
      return el("p", { text: emptyText });
    }
    const list = el("ul");
    items.forEach((item) => {
      list.appendChild(el("li", {}, [
        item.siteHref ? el("a", { href: siteUrl(item.siteHref), text: item.label }) : el("strong", { text: item.label }),
        document.createTextNode(item.reason ? ` - ${item.reason}` : item.status ? ` - ${item.status}` : "")
      ]));
    });
    return list;
  }

  function renderResults(data, answers, results, markdown) {
    const panel = el("aside", { className: "dq-results", "aria-live": "polite" });
    panel.appendChild(el("h2", { text: "Live outputs" }));
    panel.appendChild(el("p", { className: "dq-privacy-inline", text: "Answers are stored in this browser only and are not submitted anywhere." }));

    const patterns = el("section", {}, [
      el("h3", { text: "Recommended patterns" }),
      renderList(results.patterns, "No pattern selected yet.")
    ]);
    panel.appendChild(patterns);

    const decisions = el("section", {}, [
      el("h3", { text: "Decisions fixed at host pool creation" }),
      renderList(results.decisions.map((decision) => ({
        label: decision.label,
        reason: decision.value,
        siteHref: decision.source
      })), "No decisions yet.")
    ]);
    panel.appendChild(decisions);

    const readiness = el("section", {}, [
      el("h3", { text: "Dependency readiness" }),
      renderDependencyTable(results.dependencies)
    ]);
    panel.appendChild(readiness);

    const sizing = el("section", {}, [
      el("h3", { text: "Sizing estimates" }),
      renderSizingTable(results.sizing)
    ]);
    panel.appendChild(sizing);

    const parameters = el("section", {}, [
      el("h3", { text: "Deployment parameters" }),
      el("p", { text: "The generated azuredeploy.parameters.json omits localAdminPassword. Supply it securely at deployment time." }),
      el("pre", {}, [el("code", { text: JSON.stringify(results.parameters, null, 2) })]),
      renderDeploymentCommands(data, answers, results.parameters)
    ]);
    panel.appendChild(parameters);

    const report = el("section", { className: "dq-report" }, [
      el("h3", { text: "Discovery report" }),
      el("pre", {}, [el("code", { text: markdown })])
    ]);
    panel.appendChild(report);
    return panel;
  }

  function renderDependencyTable(dependencies) {
    const table = el("table", { className: "dq-table" });
    table.appendChild(el("thead", {}, [el("tr", {}, [
      el("th", { text: "Dependency" }),
      el("th", { text: "Status" })
    ])]));
    const body = el("tbody");
    dependencies.forEach((dependency) => {
      body.appendChild(el("tr", {}, [
        el("td", {}, [el("a", { href: siteUrl(dependency.siteHref), text: dependency.label })]),
        el("td", {}, [el("span", { className: `dq-pill ${dependency.status === "in place" ? "is-ready" : "is-needed"}`, text: dependency.status })])
      ]));
    });
    table.appendChild(body);
    return table;
  }

  function renderSizingTable(sizing) {
    const table = el("table", { className: "dq-table" });
    table.appendChild(el("thead", {}, [el("tr", {}, [
      el("th", { text: "Estimate" }),
      el("th", { text: "Value" }),
      el("th", { text: "Formula and source" })
    ])]));
    const body = el("tbody");
    Object.values(sizing).forEach((item) => {
      body.appendChild(el("tr", {}, [
        el("td", { text: item.label }),
        el("td", { text: String(item.value) }),
        el("td", {}, [
          document.createTextNode(`${item.formula} `),
          el("a", { href: siteUrl(item.source), target: item.source.startsWith("http") ? "_blank" : "", rel: "noopener", text: "Source" })
        ])
      ]));
    });
    table.appendChild(body);
    return table;
  }

  function buildDeploymentCommands(data, answers, parameters) {
    const templateUri = data.parameterMap.templateUri;
    const image = getImageSelection(answers);
    const hasVersion = Boolean(parameters.parameters.marketplaceImageVersion);
    const cliVersionLookup = `version=$(az vm image list -l ${image.location} -p ${image.publisher} -f ${image.offer} -s ${image.sku} --all --query "[-1].version" -o tsv)`;
    const psVersionLookup = `$version = (Get-AzVMImage -Location ${image.location} -PublisherName ${image.publisher} -Offer ${image.offer} -Skus ${image.sku} | Sort-Object { [version]$_.Version } | Select-Object -Last 1).Version`;
    const cli = [
      hasVersion ? null : cliVersionLookup,
      "az deployment group create \\",
      "  --name avdNorthStarPilot \\",
      "  --resource-group <resource-group-name> \\",
      `  --template-uri "${templateUri}" \\`,
      "  --parameters @azuredeploy.parameters.json \\",
      hasVersion ? null : "  --parameters marketplaceImageVersion=$version \\",
      "  --parameters localAdminPassword='<supply-securely>'"
    ].filter(Boolean).join("\n");
    const ps = [
      hasVersion ? null : psVersionLookup,
      "New-AzResourceGroupDeployment `",
      "  -Name avdNorthStarPilot `",
      "  -ResourceGroupName <resource-group-name> `",
      `  -TemplateUri "${templateUri}" \``,
      "  -TemplateParameterFile .\\azuredeploy.parameters.json `",
      hasVersion ? null : "  -marketplaceImageVersion $version `",
      "  -localAdminPassword (Read-Host -AsSecureString 'Local admin password')"
    ].filter(Boolean).join("\n");
    return {
      cli,
      powerShell: ps,
      versionLookup: {
        cliOneLine: cliVersionLookup,
        powerShellOneLine: psVersionLookup
      },
      hasVersion
    };
  }

  function renderDeploymentCommands(data, answers, parameters) {
    const commands = buildDeploymentCommands(data, answers, parameters);
    return el("div", { className: "dq-commands" }, [
      el("p", {}, [
        document.createTextNode("Microsoft Learn confirms Azure CLI remote templates use "),
        el("strong", { text: "--template-uri" }),
        document.createTextNode(" and local JSON parameter files use "),
        el("strong", { text: "--parameters" }),
        document.createTextNode(". Azure PowerShell remote templates use "),
        el("strong", { text: "-TemplateUri" }),
        document.createTextNode(" and local JSON parameter files use "),
        el("strong", { text: "-TemplateParameterFile" }),
        document.createTextNode(". The portal custom deployment article confirms template editing and GitHub quickstart loading, but does not confirm loading a local parameters file for this scenario.")
      ]),
      commands.hasVersion ? null : el("p", { text: "Because no exact Marketplace image version was entered, run the lookup step first and pass marketplaceImageVersion as a deployment override." }),
      el("h4", { text: "Azure CLI" }),
      el("pre", {}, [el("code", { text: commands.cli })]),
      el("h4", { text: "Azure PowerShell" }),
      el("pre", {}, [el("code", { text: commands.powerShell })])
    ]);
  }

  function downloadFile(filename, mimeType, content) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  }

  function saveAnswers(storageKey, answers) {
    localStorage.setItem(storageKey, JSON.stringify(answers));
  }

  function loadAnswers(storageKey, defaults) {
    try {
      const raw = localStorage.getItem(storageKey);
      if (!raw) {
        return defaults;
      }
      return Object.assign({}, defaults, JSON.parse(raw));
    } catch (error) {
      return defaults;
    }
  }

  async function loadData(url) {
    const response = await fetch(url, { credentials: "same-origin" });
    if (!response.ok) {
      throw new Error(`Unable to load discovery questionnaire: ${response.status}`);
    }
    return response.json();
  }

  function initWithData(root, data) {
    if (root.dataset.discoveryReady === "true") {
      return;
    }
    root.dataset.discoveryReady = "true";

    const defaults = makeDefaultAnswers(data);
    const answers = loadAnswers(data.storageKey || "avdNorthStarDiscoveryAnswers.v1", defaults);
    const state = { activeSection: 0 };
    let latestResults = computeResults(data, answers);
    let latestMarkdown = makeMarkdownReport(data, answers, latestResults);

    const fileInput = el("input", { type: "file", accept: "application/json", hidden: "hidden" });
    fileInput.addEventListener("change", async () => {
      const file = fileInput.files && fileInput.files[0];
      if (!file) {
        return;
      }
      const imported = JSON.parse(await file.text());
      Object.keys(answers).forEach((key) => delete answers[key]);
      Object.assign(answers, defaults, imported.answers || imported);
      update();
    });

    function update(mode) {
      saveAnswers(data.storageKey || "avdNorthStarDiscoveryAnswers.v1", answers);
      latestResults = computeResults(data, answers);
      latestMarkdown = makeMarkdownReport(data, answers, latestResults);
      if (mode === "results") {
        refreshResults();
      } else {
        render();
      }
    }

    function refreshResults() {
      const progress = sectionProgress(data, answers);
      const progressElement = root.querySelector(".dq-progress");
      if (progressElement) {
        progressElement.textContent = `${progress.answered} of ${progress.total} visible questions answered`;
      }
      const currentResults = root.querySelector(".dq-results");
      if (currentResults) {
        currentResults.replaceWith(renderResults(data, answers, latestResults, latestMarkdown));
      }
    }

    function render() {
      root.textContent = "";
      const shell = el("div", { className: "dq-shell" });
      const toolbar = el("div", { className: "dq-toolbar" });
      const progress = sectionProgress(data, answers);
      toolbar.appendChild(el("p", { className: "dq-progress", text: `${progress.answered} of ${progress.total} visible questions answered` }));
      toolbar.appendChild(button("Export answers", () => downloadFile("avd-discovery-answers.json", "application/json", JSON.stringify({ version: data.version, answers }, null, 2))));
      toolbar.appendChild(button("Import answers", () => fileInput.click()));
      toolbar.appendChild(button("Download parameters", () => downloadFile("azuredeploy.parameters.json", "application/json", JSON.stringify(latestResults.parameters, null, 2))));
      toolbar.appendChild(button("Download Markdown report", () => downloadFile("avd-discovery-report.md", "text/markdown", latestMarkdown)));
      toolbar.appendChild(button("Print report", () => window.print()));
      toolbar.appendChild(button("Reset", () => {
        if (window.confirm("Reset all answers in this browser?")) {
          Object.keys(answers).forEach((key) => delete answers[key]);
          Object.assign(answers, makeDefaultAnswers(data));
          update();
        }
      }, "dq-danger"));

      const main = el("div", { className: "dq-main" });
      const left = el("div", { className: "dq-left" });
      left.appendChild(renderSectionNav(data, answers, state, root, update));
      left.appendChild(renderForm(data, answers, state, update));
      main.appendChild(left);
      main.appendChild(renderResults(data, answers, latestResults, latestMarkdown));
      shell.appendChild(toolbar);
      shell.appendChild(main);
      shell.appendChild(fileInput);
      root.appendChild(shell);
    }

    render();
  }

  function sectionProgress(data, answers) {
    let total = 0;
    let answered = 0;
    asArray(data.sections).forEach((section) => {
      asArray(section.questions).forEach((question) => {
        if (!isQuestionVisible(question, answers)) {
          return;
        }
        total += 1;
        const value = answers[question.id];
        if (Array.isArray(value) ? value.length > 0 : value !== undefined && value !== null && value !== "") {
          answered += 1;
        }
      });
    });
    return { total, answered };
  }

  function button(text, handler, className) {
    const element = el("button", { type: "button", className: `dq-button ${className || ""}`, text });
    element.addEventListener("click", handler);
    return element;
  }

  async function initDiscoveryQuestionnaire() {
    const root = document.querySelector(ROOT_SELECTOR);
    if (!root) {
      return;
    }
    siteRootUrl = findSiteRoot(root);
    const dataUrl = siteUrl(root.getAttribute("data-questionnaire-src") || DEFAULT_DATA_URL);
    root.textContent = "Loading discovery questionnaire...";
    try {
      const data = await loadData(dataUrl);
      initWithData(root, data);
    } catch (error) {
      root.textContent = error.message;
      root.classList.add("dq-error");
    }
  }

  if (typeof window !== "undefined" && typeof document !== "undefined") {
    if (window.document$ && typeof window.document$.subscribe === "function") {
      window.document$.subscribe(initDiscoveryQuestionnaire);
    } else if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", initDiscoveryQuestionnaire);
    } else {
      initDiscoveryQuestionnaire();
    }
  }

  if (typeof module !== "undefined") {
    module.exports = {
      makeDefaultAnswers,
      isQuestionVisible,
      computeResults,
      buildParameters,
      buildDeploymentCommands,
      getImageSelection,
      isExactMarketplaceImageVersion,
      makeMarkdownReport,
      sizingEstimates,
      dependencyReadiness,
      recommendedPatterns
    };
  }
})();
