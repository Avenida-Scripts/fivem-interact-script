import React, { useEffect, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import Interaction, { InteractionContent } from "./Menu";
import Dialogue, { DialogueState, DEFAULT_DIALOGUE } from "./Dialogue";
import { isEnvBrowser } from "../utils/misc";

type UIState = {
  visible: boolean;
  message: string;
  bind: string;
  useOnlyBind: boolean;
  hintOnly: boolean;
  hintIcon: string;
  hintColor: string;
  flash: boolean;
  choices: Array<{ bind: string; message: string; hintColor?: string }>;
};

const DEFAULT_STATE: UIState = {
  visible:     false,
  message:     "",
  bind:        "E",
  useOnlyBind: false,
  hintOnly:    true,
  hintIcon:    "pin",
  hintColor:   "#ffffff",
  flash:       false,
  choices:     [],
};

const App: React.FC = () => {
  const [ui, setUI]   = useState<UIState>(DEFAULT_STATE);
  const [dlg, setDlg] = useState<DialogueState>(DEFAULT_DIALOGUE);

  useEffect(() => {
    const cls = ["dark", "select-none", "overflow-hidden", "font-sans", "min-h-screen"];
    document.body.classList.add(...cls);
    // Transparent in game (DUI sprite), black in dev so the white text stays readable
    document.body.style.background = isEnvBrowser() ? "#000000" : "transparent";
    return () => {
      document.body.classList.remove(...cls);
      document.body.style.background = "";
    };
  }, []);

  useNuiEvent<any>("manageTextUI", (data) => {
    setUI(prev => ({
      ...prev,
      visible:     Boolean(data?.Visible),
      message:     String(data?.Message ?? ""),
      bind:        String(data?.Bind ?? "E"),
      useOnlyBind: Boolean(data?.UseOnlyBind),
      hintOnly:    Boolean(data?.HintOnly ?? true),
      hintIcon:    String(data?.HintIcon ?? "pin"),
      hintColor:   String(data?.HintColor ?? "#ffffff"),
      flash:       false,
      choices:     Array.isArray(data?.Choices) ? data.Choices : [],
    }));
  });

  useNuiEvent("interactFlash", () => {
    setUI(prev => ({ ...prev, flash: true }));
    setTimeout(() => setUI(prev => ({ ...prev, flash: false })), 400);
  });

  useNuiEvent<any>("showDialogue", (data) => {
    setDlg({
      visible:  true,
      npcName:  String(data?.npcName  ?? ""),
      npcTag:   String(data?.npcTag   ?? ""),
      message:  String(data?.message  ?? ""),
      elements: Array.isArray(data?.elements) ? data.elements : [],
    });
  });

  useNuiEvent("closeDialogue", () => {
    setDlg(prev => ({ ...prev, visible: false }));
  });

  useNuiEvent<any>("changeDialogue", (data) => {
    setDlg(prev => ({
      ...prev,
      message:  String(data?.message ?? prev.message),
      elements: Array.isArray(data?.elements) ? data.elements : prev.elements,
    }));
  });

  // In a browser (npm run start) : render a preview bench to guide the design work
  if (isEnvBrowser()) return <DevPreview />;

  return (
    <>
      <Interaction
        visible={ui.visible}
        message={ui.message}
        bind={ui.bind}
        useOnlyBind={ui.useOnlyBind}
        hintOnly={ui.hintOnly}
        hintIcon={ui.hintIcon}
        hintColor={ui.hintColor}
        flash={ui.flash}
        choices={ui.choices}
      />
      <Dialogue {...dlg} />
    </>
  );
};

/* ------------------------------------------------------------------ */
/*  Dev preview — never rendered in game (gated by isEnvBrowser)      */
/* ------------------------------------------------------------------ */

const Cell: React.FC<{ caption: string; children: React.ReactNode }> = ({ caption, children }) => (
  <div
    style={{
      position:     "relative",
      display:      "flex",
      alignItems:   "center",
      minHeight:    "150px",
      paddingLeft:  "120px",
      borderBottom: "1px solid rgba(255,255,255,0.08)",
    }}
  >
    <span
      style={{
        position:      "absolute",
        top:           "10px",
        left:          "16px",
        fontSize:      "11px",
        letterSpacing: "0.14em",
        textTransform: "uppercase",
        color:         "rgba(255,255,255,0.35)",
        fontFamily:    "monospace",
      }}
    >
      {caption}
    </span>
    {children}
  </div>
);

// Loops hint ↔ hold to preview the show/hide animation
const AnimatedDemo: React.FC = () => {
  const [hint, setHint] = useState(true);
  useEffect(() => {
    const t = setInterval(() => setHint(h => !h), 1900);
    return () => clearInterval(t);
  }, []);
  return <InteractionContent visible message="Open the trunk" bind="E" hintOnly={hint} hintIcon="storage" hintColor="#feae00" />;
};

const DevPreview: React.FC = () => (
  <div style={{ minHeight: "100vh", width: "100%", background: "#000", fontFamily: "'Montserrat', sans-serif", paddingBottom: "22rem" }}>
    {/* dialogue preview (rendered fixed bottom-center, like in game). Edit Dialogue.tsx → live HMR. */}
    <Cell caption="dialogue — Tom (hotel front desk) — see bottom of page ↓">
      <span style={{ color: "rgba(255,255,255,0.35)", fontFamily: "monospace", fontSize: "12px" }}>
        rendered as a fixed overlay (bottom-center)
      </span>
    </Cell>
    <Dialogue
      visible
      npcName="Tom"
      npcTag="Receptionist"
      message="There you are! Welcome to the Diamond. Are you settled in your room?"
      elements={[
        { label: "Yes, all good." },
        { label: "What is this place?" },
      ]}
    />

    <Cell caption="animation — show / hide (looping)">
      <AnimatedDemo />
    </Cell>

    <Cell caption="hint — far away (icon only)">
      <InteractionContent visible message="Open the trunk" bind="E" hintOnly hintIcon="storage" hintColor="#feae00" />
    </Cell>

    <Cell caption="hold — single interaction">
      <InteractionContent visible message="Open the trunk" bind="E" hintIcon="storage" hintColor="#feae00" />
    </Cell>

    <Cell caption="hold — useOnlyBind (key only)">
      <InteractionContent visible message="" bind="F" useOnlyBind hintIcon="car" hintColor="#3b7ea2" />
    </Cell>

    <Cell caption="hold — multiple interactions">
      <InteractionContent
        visible
        message=""
        bind="E"
        hintIcon="interact"
        hintColor="#feae00"
        choices={[
          { bind: "E", message: "Inspect the vehicle",  hintColor: "#feae00" },
          { bind: "F", message: "Open the trunk",       hintColor: "#3b7ea2" },
          { bind: "G", message: "Pick the lock",        hintColor: "#b82121" },
        ]}
      />
    </Cell>
  </div>
);

export default App;
