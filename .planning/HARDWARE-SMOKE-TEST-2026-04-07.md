# Hardware smoke test — integrated merge stack

**Build target:** `main @ 689b5ae` (C + B + D + Phase 0 hardware fixes + Q\&A diagnostic)
**Device:** Art's Secret Castle (iPhone, iOS 26.4) — wireless
**Glasses:** Even Realities G1 — **power-cycle before first test** to clear any firmware debug-mode state from prior sessions
**Deploy:** `flutter run --release -d 00008150-001514CC3C00401C` (release — debug is sim-only per CLAUDE.md)

## Pre-test

- **Power-cycle G1 glasses** (both L + R) before connecting
- Cold-launch Helix (force-quit first if already running)
- Pair/connect both L + R via in-app flow
- Confirm Settings → Transcription Backend is on Apple Cloud (most reliable per project findings)
- Confirm an LLM provider API key is configured (OpenAI gpt-4.1-mini is the default smart model)
- Keep Xcode console (or Console.app filtered to `Helix`/`Even Companion`) open for the Q\&A diagnostic filter

&#x20;

---

## 1. Left-eye HUD regression — CRITICAL

**Previous symptom:** L eye stuck on "Even AI Listening" screen while R eye streamed the actual answer. Fixed on main by `ddaab66` (reverted append-delta scheme → full-canvas). Not yet hardware-verified.

- Start a live listening session
- Trigger a question verbally ("What time is it in Tokyo?")
- Watch BOTH lenses during streaming:
  - **L eye** shows the answer text streaming in (NOT stuck on "Listening")
  - **R eye** shows the same answer text streaming in
  - Both lenses show the SAME page at the same time
  - No flicker/flash between "Listening" screen and answer
- After answer completes, both lenses show final text
- Press right touchpad → next page (if multi-page)
- Press left touchpad → previous page

**If L eye is still stuck:** capture a Console log with filter `G1DBG` and report. This is the highest-priority bug — if it repros, stop testing and tell me.Results - Still shows EvenAI Listening for brief moment (once only on left eye, once on both eye). Here is the log: default	22:31:30.505537-0700	backboardd	SyncDBV Transaction | ID=3141567 | SDR.Nits=17.935 | Applied.Compensation=1.800 | Nits.Cap=383.195 | DynamicSlider.Cap=383.195 | Brightness.Limit=383.195 | Trusted.Lux=12.644 | HDR.Nits=17.935 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.320 | IndicatorBrightness.Cap=383.195 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.521399-0700	backboardd	SyncDBV Transaction | ID=3141568 | SDR.Nits=17.935 | Applied.Compensation=1.800 | Nits.Cap=383.129 | DynamicSlider.Cap=383.129 | Brightness.Limit=383.129 | Trusted.Lux=12.644 | HDR.Nits=17.935 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.320 | IndicatorBrightness.Cap=383.129 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.537883-0700	backboardd	SyncDBV Transaction | ID=3141569 | SDR.Nits=17.935 | Applied.Compensation=1.800 | Nits.Cap=383.063 | DynamicSlider.Cap=383.063 | Brightness.Limit=383.063 | Trusted.Lux=12.644 | HDR.Nits=17.935 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.320 | IndicatorBrightness.Cap=383.063 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.538307-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.538320-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.538330-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.554588-0700	backboardd	SyncDBV Transaction | ID=3141570 | SDR.Nits=17.935 | Applied.Compensation=1.800 | Nits.Cap=382.998 | DynamicSlider.Cap=382.998 | Brightness.Limit=382.998 | Trusted.Lux=12.644 | HDR.Nits=17.935 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.320 | IndicatorBrightness.Cap=382.998 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.555110-0700	CommCenter	#I \[\<private>] queueing qmux pdu for svc=1 client=4 (txid=16411 msgid=0x555b) \[tx-slot=1, rx-pending=0]

default	22:31:30.555179-0700	CommCenter	#I \[\<private>] queueing qmux pdu for svc=1 client=9 (txid=6340 msgid=0x555b) \[tx-slot=2, rx-pending=0]

default	22:31:30.555389-0700	CommCenter	QMI: Svc=0x01(WDS) Req MsgId=0x555b Sim=1 Bin=\[\<private>]

default	22:31:30.555946-0700	CommCenter	QMI: Svc=0x01(WDS) Req MsgId=0x555b Sim=1 Bin=\[\<private>]

default	22:31:30.573106-0700	backboardd	SyncDBV Transaction | ID=3141571 | SDR.Nits=17.934 | Applied.Compensation=1.800 | Nits.Cap=382.933 | DynamicSlider.Cap=382.933 | Brightness.Limit=382.933 | Trusted.Lux=12.644 | HDR.Nits=17.934 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.320 | IndicatorBrightness.Cap=382.933 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.573510-0700	CommCenter	QMI: Svc=0x01(WDS) Resp MsgId=0x555b Sim=1 Bin=\[\<private>]

default	22:31:30.573571-0700	kernel	Unified Timer Running ID #0 Timer duration 2, Timer Expiry Time 24773194744242

default	22:31:30.573723-0700	CommCenter	QMI: Svc=0x01(WDS) Resp MsgId=0x555b Sim=1 Bin=\[\<private>]

default	22:31:30.589734-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: B8EDA529-98C6-4CD5-911A-EF1043511E29

default	22:31:30.589754-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:30.590027-0700	backboardd	SyncDBV Transaction | ID=3141572 | SDR.Nits=17.934 | Applied.Compensation=1.800 | Nits.Cap=382.868 | DynamicSlider.Cap=382.868 | Brightness.Limit=382.868 | Trusted.Lux=12.644 | HDR.Nits=17.934 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.868 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.590244-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:30.590356-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload B8EDA529-98C6-4CD5-911A-EF1043511E29 for XPC participant content source \<private>

default	22:31:30.590374-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:30.590390-0700	Even Companion	Cancelling watchdog

default	22:31:30.606792-0700	backboardd	SyncDBV Transaction | ID=3141573 | SDR.Nits=17.934 | Applied.Compensation=1.800 | Nits.Cap=382.804 | DynamicSlider.Cap=382.804 | Brightness.Limit=382.804 | Trusted.Lux=12.644 | HDR.Nits=17.934 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.804 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.621524-0700	backboardd	SyncDBV Transaction | ID=3141574 | SDR.Nits=17.934 | Applied.Compensation=1.800 | Nits.Cap=382.740 | DynamicSlider.Cap=382.740 | Brightness.Limit=382.740 | Trusted.Lux=12.644 | HDR.Nits=17.934 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.740 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.629445-0700	mDNSResponder	\[A(5af10412, 71d881f3)] Sent a previous IPv4 mDNS response over multicast

default	22:31:30.629673-0700	mDNSResponder	\[A(5af10412, 32ee0b73)] Sent a previous IPv6 mDNS response over multicast

default	22:31:30.630214-0700	mDNSResponder	\[A(7ce8d1da, 55621938)] Sent a previous IPv4 mDNS response over multicast

default	22:31:30.630327-0700	mDNSResponder	\[A(7ce8d1da, b6b56638)] Sent a previous IPv6 mDNS response over multicast

default	22:31:30.636888-0700	backboardd	SyncDBV Transaction | ID=3141575 | SDR.Nits=17.934 | Applied.Compensation=1.800 | Nits.Cap=382.677 | DynamicSlider.Cap=382.677 | Brightness.Limit=382.677 | Trusted.Lux=12.644 | HDR.Nits=17.934 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.677 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.637981-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.638000-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.638243-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.654371-0700	backboardd	SyncDBV Transaction | ID=3141576 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.614 | DynamicSlider.Cap=382.614 | Brightness.Limit=382.614 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.614 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.664915-0700	backboardd	\[ALS] ts=933227.768 lux=11.315\<private> xy=(0.444 0.390) chs=\[132 210 448 841 1290] CCT1=3144.198 gain=512x mode=\<private> subsamples=120 rawLux=11.406 nits=50 xTalk=\[0 1 3 4 4] status=0x0B copyEvent=0

default	22:31:30.666196-0700	backboardd	ScheduleSetBrightnessIn\_block\_invoke: enter WaitUntil late 0.022666 millisecond (1151438 / 1151438)

default	22:31:30.666706-0700	backboardd	SyncDBV Transaction | ID=3141577 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.614 | DynamicSlider.Cap=382.614 | Brightness.Limit=382.614 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.614 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.671274-0700	backboardd	SyncDBV Transaction | ID=3141578 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.551 | DynamicSlider.Cap=382.551 | Brightness.Limit=382.551 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.317 | IndicatorBrightness.Cap=382.551 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.689542-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 1DC29542-DA37-4B3D-81BE-6B4206DF0D22

default	22:31:30.689558-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:30.690543-0700	backboardd	SyncDBV Transaction | ID=3141579 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.489 | DynamicSlider.Cap=382.489 | Brightness.Limit=382.489 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.314 | IndicatorBrightness.Cap=382.489 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.690778-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:30.690874-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 1DC29542-DA37-4B3D-81BE-6B4206DF0D22 for XPC participant content source \<private>

default	22:31:30.690893-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:30.690974-0700	Even Companion	Cancelling watchdog

default	22:31:30.691093-0700	kernel	wlan0:com.apple.p2p.en0:   set Datapath Open needsTrigger 0

default	22:31:30.705326-0700	backboardd	SyncDBV Transaction | ID=3141580 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.427 | DynamicSlider.Cap=382.427 | Brightness.Limit=382.427 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.314 | IndicatorBrightness.Cap=382.427 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.721530-0700	backboardd	SyncDBV Transaction | ID=3141581 | SDR.Nits=17.933 | Applied.Compensation=1.800 | Nits.Cap=382.365 | DynamicSlider.Cap=382.365 | Brightness.Limit=382.365 | Trusted.Lux=12.644 | HDR.Nits=17.933 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.314 | IndicatorBrightness.Cap=382.365 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.724796-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.737534-0700	backboardd	SyncDBV Transaction | ID=3141582 | SDR.Nits=17.932 | Applied.Compensation=1.800 | Nits.Cap=382.304 | DynamicSlider.Cap=382.304 | Brightness.Limit=382.304 | Trusted.Lux=12.644 | HDR.Nits=17.932 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.314 | IndicatorBrightness.Cap=382.304 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.738017-0700	kernel	\[1032216.604125]: vm: segments queued for swapout: 0 regular, 6150 freezer, 0 donate, 0 ripe, 0 darwkwake, 6150 totalvm: segments queued for swapout: 0 regular, 5476 freezer, 0 donate, 0 ripe, 0 darwkwake, 5476 tota

default	22:31:30.738043-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.738228-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.738291-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.743236-0700	runningboardd	Assertion did invalidate due to timeout: 36-123-976853 (target:\[xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}:47521])

error	22:31:30.744596-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.754101-0700	backboardd	SyncDBV Transaction | ID=3141583 | SDR.Nits=17.932 | Applied.Compensation=1.800 | Nits.Cap=382.243 | DynamicSlider.Cap=382.243 | Brightness.Limit=382.243 | Trusted.Lux=12.644 | HDR.Nits=17.932 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.314 | IndicatorBrightness.Cap=382.243 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.764569-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.771528-0700	backboardd	SyncDBV Transaction | ID=3141584 | SDR.Nits=17.932 | Applied.Compensation=1.800 | Nits.Cap=382.183 | DynamicSlider.Cap=382.183 | Brightness.Limit=382.183 | Trusted.Lux=12.644 | HDR.Nits=17.932 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.310 | IndicatorBrightness.Cap=382.183 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.784580-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.788395-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 5900895F-66BF-4598-BF93-7322ABCC2D99

default	22:31:30.788412-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:30.789544-0700	backboardd	SyncDBV Transaction | ID=3141585 | SDR.Nits=17.932 | Applied.Compensation=1.800 | Nits.Cap=382.123 | DynamicSlider.Cap=382.123 | Brightness.Limit=382.123 | Trusted.Lux=12.644 | HDR.Nits=17.932 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.310 | IndicatorBrightness.Cap=382.123 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.789859-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:30.789901-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 5900895F-66BF-4598-BF93-7322ABCC2D99 for XPC participant content source \<private>

default	22:31:30.789925-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:30.789947-0700	Even Companion	Cancelling watchdog

error	22:31:30.806560-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.806638-0700	backboardd	SyncDBV Transaction | ID=3141586 | SDR.Nits=17.932 | Applied.Compensation=1.800 | Nits.Cap=382.063 | DynamicSlider.Cap=382.063 | Brightness.Limit=382.063 | Trusted.Lux=12.644 | HDR.Nits=17.932 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.310 | IndicatorBrightness.Cap=382.063 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.821604-0700	backboardd	SyncDBV Transaction | ID=3141587 | SDR.Nits=17.931 | Applied.Compensation=1.800 | Nits.Cap=382.004 | DynamicSlider.Cap=382.004 | Brightness.Limit=382.004 | Trusted.Lux=12.644 | HDR.Nits=17.931 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.310 | IndicatorBrightness.Cap=382.004 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.823466-0700	kernel	wlan0:com.apple.p2p.en0:   set Datapath Open needsTrigger 0

error	22:31:30.824698-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

error	22:31:30.827606-0700	kernel	log,552E9358-8DE4-30D7-B786-D73DDE43F46D,105e7c0

default	22:31:30.837409-0700	backboardd	SyncDBV Transaction | ID=3141588 | SDR.Nits=17.931 | Applied.Compensation=1.800 | Nits.Cap=381.945 | DynamicSlider.Cap=381.945 | Brightness.Limit=381.945 | Trusted.Lux=12.644 | HDR.Nits=17.931 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.310 | IndicatorBrightness.Cap=381.945 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.837698-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.837707-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.837987-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

error	22:31:30.844515-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.854258-0700	backboardd	SyncDBV Transaction | ID=3141589 | SDR.Nits=17.931 | Applied.Compensation=1.800 | Nits.Cap=381.887 | DynamicSlider.Cap=381.887 | Brightness.Limit=381.887 | Trusted.Lux=12.644 | HDR.Nits=17.931 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.887 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.864579-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.872148-0700	backboardd	SyncDBV Transaction | ID=3141590 | SDR.Nits=17.931 | Applied.Compensation=1.800 | Nits.Cap=381.829 | DynamicSlider.Cap=381.829 | Brightness.Limit=381.829 | Trusted.Lux=12.644 | HDR.Nits=17.931 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.829 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.884517-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.890300-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: D5EBD6B9-46E1-4CB1-928B-AB7C90B33EBB

default	22:31:30.890316-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:30.891010-0700	locationd	{"msg":"onAvengerAdvertisementDetected convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"ADLAvenger"}

default	22:31:30.891081-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"ADLAvenger"}

default	22:31:30.891324-0700	locationd	\<private>

default	22:31:30.891482-0700	locationd	{"msg":"onAvengerAdvertisementDetected: got avenger advertisement", "subHarvester":"Avenger"}

default	22:31:30.891736-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:30.891755-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload D5EBD6B9-46E1-4CB1-928B-AB7C90B33EBB for XPC participant content source \<private>

default	22:31:30.891781-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:30.891979-0700	Even Companion	Cancelling watchdog

default	22:31:30.892005-0700	backboardd	SyncDBV Transaction | ID=3141591 | SDR.Nits=17.931 | Applied.Compensation=1.800 | Nits.Cap=381.769 | DynamicSlider.Cap=381.769 | Brightness.Limit=381.769 | Trusted.Lux=12.644 | HDR.Nits=17.931 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.769 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.892067-0700	locationd	{"msg":"convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"Avenger"}

default	22:31:30.892088-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"Avenger"}

default	22:31:30.905910-0700	backboardd	SyncDBV Transaction | ID=3141592 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.714 | DynamicSlider.Cap=381.714 | Brightness.Limit=381.714 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.714 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.906465-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.919569-0700	backboardd	\[ALS] ts=933228.022 lux=11.319\<private> xy=(0.456 0.404) chs=\[112 211 445 847 1285] CCT1=3009.762 gain=512x mode=\<private> subsamples=120 rawLux=11.409 nits=50 xTalk=\[0 1 3 4 5] status=0x0B copyEvent=0

default	22:31:30.922095-0700	backboardd	ScheduleSetBrightnessIn\_block\_invoke: enter WaitUntil late 0.086583 millisecond (1151439 / 1151439)

default	22:31:30.923250-0700	backboardd	SyncDBV Transaction | ID=3141593 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.656 | DynamicSlider.Cap=381.656 | Brightness.Limit=381.656 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.656 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.923696-0700	backboardd	SyncDBV Transaction | ID=3141594 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.656 | DynamicSlider.Cap=381.656 | Brightness.Limit=381.656 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.656 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.926039-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.936688-0700	backboardd	SyncDBV Transaction | ID=3141595 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.600 | DynamicSlider.Cap=381.600 | Brightness.Limit=381.600 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.307 | IndicatorBrightness.Cap=381.600 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.937479-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.937505-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.937809-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:30.938137-0700	locationd	visitKFFilteredPressure,nowAP,797319090.937752,nowAOP,1032216817853,filteredPressure,101520.890625,pressureTimestamp,1032214064258,kfElevation,31.291750,wallTimePressureCorrected,797319088.185920,wallTimeKFCorrected,797319090.904806,temperatureDerivative,0.000000,absAltUnc,14.453908

error	22:31:30.944542-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.945341-0700	runningboardd	\[xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}:47521] Set jetsam priority to 0 \[0] flag\[1]

default	22:31:30.945708-0700	runningboardd	Calculated state for xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}: running-suspended (role: None) (endowments: (null))

default	22:31:30.946197-0700	powerd	Process runningboardd.36 Released SystemIsActive "xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}36-123-976853:\[helix.liveactivity-17E1795A3120]" age:00:00:03  id:51539640925 \[System: PrevIdle SysAct]

default	22:31:30.946352-0700	runningboardd	Released power assertion with ID 33373

default	22:31:30.947468-0700	SpringBoard	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.947561-0700	audiomxd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.947918-0700	UserEventAgent	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.948276-0700	IDSCredentialsAgent	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.948549-0700	privacyaccountingd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.949448-0700	Even Companion	\<private>

default	22:31:30.949465-0700	PerfPowerServices	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.949510-0700	Even Companion	\<private>

default	22:31:30.949930-0700	wifid	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.950320-0700	Even Companion	\<private>

default	22:31:30.950336-0700	locationd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.950922-0700	symptomsd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.951248-0700	WirelessRadioManagerd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.951324-0700	accessoryd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.951662-0700	useractivityd	Received state update for 47521 (xpcservice\<com.artjiang.helix.liveactivity(\[osservice\<com.apple.chronod>:123])>{vt hash: 248728869}\[uuid:540D8C63-38B0-4544-B15B-4ED0FF8AD9BE]{definition:com.artjiang.helix.liveactivity\[extension]\[client]}, running-suspended-NotVisible

default	22:31:30.954896-0700	backboardd	SyncDBV Transaction | ID=3141596 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.544 | DynamicSlider.Cap=381.544 | Brightness.Limit=381.544 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.304 | IndicatorBrightness.Cap=381.544 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.964929-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.973330-0700	backboardd	SyncDBV Transaction | ID=3141597 | SDR.Nits=17.930 | Applied.Compensation=1.800 | Nits.Cap=381.487 | DynamicSlider.Cap=381.487 | Brightness.Limit=381.487 | Trusted.Lux=12.644 | HDR.Nits=17.930 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.304 | IndicatorBrightness.Cap=381.487 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:30.988570-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:30.990541-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: F9F3DE1C-A598-4A71-9BB1-B637AEC270F6

default	22:31:30.990608-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:30.990942-0700	backboardd	SyncDBV Transaction | ID=3141598 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.431 | DynamicSlider.Cap=381.431 | Brightness.Limit=381.431 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.304 | IndicatorBrightness.Cap=381.431 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:30.991175-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:30.991276-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload F9F3DE1C-A598-4A71-9BB1-B637AEC270F6 for XPC participant content source \<private>

default	22:31:30.991297-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:30.991318-0700	Even Companion	Cancelling watchdog

default	22:31:31.002458-0700	kernel	wlan0:com.apple.p2p.awdl0: monitorAWDLState\[10135] : Active Sockets false ValidSvc 2 NumAirplay 0 AFHandlePending 0 TimeOfLastAFHandleRequest 204 ms

default	22:31:31.002511-0700	kernel	wlan0:com.apple.p2p.awdl0: monitorAWDLState\[10233]: BonJourTrig 1 ValidSvc 2 RTApp 0 TSReq 0 HasActAirDrop 0 SocketsActive 0

default	22:31:31.002521-0700	kernel	wlan0:com.apple.p2p.awdl0: setScheduleState\[11035]: reason:UserTriggered sc:Low Power and force:NO, AWDL-restore:No

default	22:31:31.004533-0700	backboardd	SyncDBV Transaction | ID=3141599 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.377 | DynamicSlider.Cap=381.377 | Brightness.Limit=381.377 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.304 | IndicatorBrightness.Cap=381.377 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.004941-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.020661-0700	backboardd	SyncDBV Transaction | ID=3141600 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.322 | DynamicSlider.Cap=381.322 | Brightness.Limit=381.322 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.304 | IndicatorBrightness.Cap=381.322 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.024898-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.037606-0700	backboardd	SyncDBV Transaction | ID=3141601 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.267 | DynamicSlider.Cap=381.267 | Brightness.Limit=381.267 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.302 | IndicatorBrightness.Cap=381.267 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.037858-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.037869-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.038137-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

error	22:31:31.044573-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.054567-0700	backboardd	SyncDBV Transaction | ID=3141602 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.213 | DynamicSlider.Cap=381.213 | Brightness.Limit=381.213 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.302 | IndicatorBrightness.Cap=381.213 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.064589-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.070863-0700	backboardd	SyncDBV Transaction | ID=3141603 | SDR.Nits=17.929 | Applied.Compensation=1.800 | Nits.Cap=381.159 | DynamicSlider.Cap=381.159 | Brightness.Limit=381.159 | Trusted.Lux=12.644 | HDR.Nits=17.929 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.302 | IndicatorBrightness.Cap=381.159 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.084563-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.088915-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 19766BEB-CFDA-45DA-B331-6130F9E7D293

default	22:31:31.089018-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.090315-0700	backboardd	SyncDBV Transaction | ID=3141604 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=381.103 | DynamicSlider.Cap=381.103 | Brightness.Limit=381.103 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.302 | IndicatorBrightness.Cap=381.103 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.090636-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.090646-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 19766BEB-CFDA-45DA-B331-6130F9E7D293 for XPC participant content source \<private>

default	22:31:31.090663-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.090678-0700	Even Companion	Cancelling watchdog

error	22:31:31.109261-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.110069-0700	backboardd	SyncDBV Transaction | ID=3141605 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=381.052 | DynamicSlider.Cap=381.052 | Brightness.Limit=381.052 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.302 | IndicatorBrightness.Cap=381.052 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.111582-0700	locationd	os\_transaction created: (\<private>) \<private>

default	22:31:31.111682-0700	locationd	os\_transaction released: (\<private>) \<private>

default	22:31:31.120919-0700	backboardd	SyncDBV Transaction | ID=3141606 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=381.000 | DynamicSlider.Cap=381.000 | Brightness.Limit=381.000 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=381.000 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.124732-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

error	22:31:31.133919-0700	wifid	WiFiLQAMgrLinkRecommendationNotify: channel score: chq=3, tx-lat=3, rx-lat=5, tx-loss=5, rx-loss=5, txPer=0.0%, p95-lat=72, RT=0x0, link-recommendation=0x0

default	22:31:31.137906-0700	backboardd	SyncDBV Transaction | ID=3141607 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=380.948 | DynamicSlider.Cap=380.948 | Brightness.Limit=380.948 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.948 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.137998-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.138017-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.138109-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

error	22:31:31.144558-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.150846-0700	kernel	wlan0:com.apple.p2p.awdl0: isInfraRealtimePacketThresholdAllowed allowed:0 option:0 threshold:50 noRegistrations:1 cachedPeerCount:0 fastDiscoveryInactive:0 fastDiscoveryOnSince:118278917

default	22:31:31.150878-0700	kernel	wlan0:com.apple.p2p.awdl0: peerChannelSteer: PEER\_CHANNEL\_STEER isSteeringRequired 0 Attempt Count 0

default	22:31:31.150899-0700	kernel	wlan0:com.apple.p2p.awdl0: peerChannelSteer: PEER\_CHANNEL\_STEER isRestartSteeringRequired is false

default	22:31:31.154959-0700	backboardd	SyncDBV Transaction | ID=3141608 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=380.896 | DynamicSlider.Cap=380.896 | Brightness.Limit=380.896 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.896 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.159606-0700	Even Companion	\<private>

default	22:31:31.159725-0700	Even Companion	\<private>

default	22:31:31.160530-0700	Even Companion	\<private>

default	22:31:31.160609-0700	Even Companion	\<private>

error	22:31:31.164544-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.173264-0700	backboardd	SyncDBV Transaction | ID=3141609 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=380.844 | DynamicSlider.Cap=380.844 | Brightness.Limit=380.844 | Trusted.Lux=12.644 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.844 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.174520-0700	backboardd	\[ALS] ts=933228.276 lux=11.268\<private> xy=(0.453 0.399) chs=\[118 210 442 845 1285] CCT1=3029.443 gain=512x mode=\<private> subsamples=120 rawLux=11.299 nits=50 xTalk=\[0 0 1 2 3] status=0x0B copyEvent=0

default	22:31:31.174961-0700	backboardd	Lux | RampIsRunning=NO StartLux=18.50 TargetLux=12.51 ShouldRamp=NO

default	22:31:31.174973-0700	backboardd	Lux | RampIsRunning=NO StartLux=20.62 TargetLux=12.51 ShouldRamp=NO

default	22:31:31.175514-0700	backboardd	\[BRT update: Fast EDR]: headroom: 1.20 ->  1.00 t: 0.000000

default	22:31:31.175542-0700	backboardd	trusted Lux: 12.510411, trusted capped Lux: 12.510411

default	22:31:31.175749-0700	backboardd	ScheduleSetBrightnessIn\_block\_invoke: enter WaitUntil late 0.018333 millisecond (1151440 / 1151440)

default	22:31:31.176187-0700	backboardd	SyncDBV Transaction | ID=3141610 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=380.844 | DynamicSlider.Cap=380.844 | Brightness.Limit=380.844 | Trusted.Lux=12.510 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.844 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.176310-0700	backboardd	Lux | RampIsRunning=NO StartLux=18.50 TargetLux=12.51 ShouldRamp=NO

default	22:31:31.176362-0700	backboardd	Lux | RampIsRunning=NO StartLux=20.62 TargetLux=12.51 ShouldRamp=NO

default	22:31:31.176712-0700	backboardd	SyncDBV Transaction | ID=3141611 | SDR.Nits=17.928 | Applied.Compensation=1.800 | Nits.Cap=380.844 | DynamicSlider.Cap=380.844 | Brightness.Limit=380.844 | Trusted.Lux=12.510 | HDR.Nits=17.928 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.844 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.181888-0700	Even Companion	\<private>

default	22:31:31.182022-0700	Even Companion	\<private>

default	22:31:31.182423-0700	Even Companion	\<private>

error	22:31:31.185058-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.191677-0700	backboardd	SyncDBV Transaction | ID=3141612 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.793 | DynamicSlider.Cap=380.793 | Brightness.Limit=380.793 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.299 | IndicatorBrightness.Cap=380.793 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.191895-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 709250E4-073E-4ECC-B1DA-38AA43310B9A

default	22:31:31.191906-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.192297-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.192305-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 709250E4-073E-4ECC-B1DA-38AA43310B9A for XPC participant content source \<private>

default	22:31:31.192313-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.192323-0700	Even Companion	Cancelling watchdog

default	22:31:31.205887-0700	backboardd	SyncDBV Transaction | ID=3141613 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.742 | DynamicSlider.Cap=380.742 | Brightness.Limit=380.742 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.297 | IndicatorBrightness.Cap=380.742 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.206058-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.213177-0700	kernel	FSM LQM\_FSM: in state: LQM\_FSM\_STATE\_ACTIVE got event: LQM\_FSM\_EVENT\_TIMER moved into: LQM\_FSM\_STATE\_ACTIVE

default	22:31:31.217099-0700	kernel	wlan0:com.apple.p2p.en0:   set Datapath Open needsTrigger 0

default	22:31:31.221261-0700	backboardd	SyncDBV Transaction | ID=3141614 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.691 | DynamicSlider.Cap=380.691 | Brightness.Limit=380.691 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.297 | IndicatorBrightness.Cap=380.691 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.226640-0700	locationd	{"msg":"onAvengerAdvertisementDetected convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"ADLAvenger"}

default	22:31:31.226713-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"ADLAvenger"}

default	22:31:31.226856-0700	locationd	\<private>

error	22:31:31.226910-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.227063-0700	locationd	{"msg":"onAvengerAdvertisementDetected: got avenger advertisement", "subHarvester":"Avenger"}

default	22:31:31.227087-0700	locationd	{"msg":"convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"Avenger"}

default	22:31:31.227109-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"Avenger"}

default	22:31:31.233711-0700	kernel	wlan0:com.apple.p2p.en0: IO80211PeerManager::reportDataPathEvents APPLE80211\_M\_RSSI\_CHANGED RSSI -68 noise -94 snr 26. Core0Rssi:-69 Core1Rssi:-71

default	22:31:31.234422-0700	wifid	\_\_WiFiDeviceProcessRSSIEvent Feeding RSSI data to LQM - RSSI:-68 Core0-RSSI:-69 Core1-RSSI:-71

default	22:31:31.235403-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : BSS List info for network : jff : chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.235424-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment for network : jff : bssCount: \[3] chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.235455-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment is Multi AP for jff(90:d0:92:4a:9c:d8). Last applied environment is Multi AP. Early exit ? : \[1]. augmented from scan results ? : \[1]

default	22:31:31.237924-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.237945-0700	wifid	\_\_WiFiLQAMgrLogRoamCache: CurrentBSS {jff - 90:d0:92:4a:9c:d8} {-73 dbm, 8, 1858 ms edgeBSS} RoamCache - {{90:d0:92:4a:9c:dc, RSSI: -76 dBm, CH: 132, Flags: 0, Age: 58 ms}}, , CacheAge: 21.95, Valid: NO

default	22:31:31.237970-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.238095-0700	backboardd	SyncDBV Transaction | ID=3141615 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.641 | DynamicSlider.Cap=380.641 | Brightness.Limit=380.641 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.297 | IndicatorBrightness.Cap=380.641 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.238162-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.240521-0700	wifid	\_\_WiFiLQAMgrLogStats(\<redacted>:Stationary): InfraUptime:703.2secs Channel: 48 Bandwidth: 80Mhz Rssi: -68 {-69 -71} Cca: 35 (S:17 O:18 I:0) Snr: 26 BcnPer: 0.0% (42, 50.0%) TxFrameCnt: 9642 TxPer: 0.0% TxReTrans: 2545 TxRetryRatio: 26.4% RxFrameCnt: 598 RxRetryFrames: 0 RxRetryRatio: 0.0% TxRate: 288235 RxRate: 648529 FBRate: 144117 TxFwFrms: 18 TxFwFail: 0 Noise: -94 {-94 -94 0} time: 5.3secs fgApp: \<private> V: T Band: 5GHz

default	22:31:31.244585-0700	WirelessRadioManagerd	\<private>

error	22:31:31.244591-0700	wifid	LQM-WiFi: WeightAvgLQM isPosted=1 rssi=<-70:-70> snr=<20:20>txRate=<216176:216176> rxRate=<648529:648529>

default	22:31:31.244628-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

error	22:31:31.246232-0700	wifid	LQM-WiFi: rxStart=11114 rxBadPLCP=25 rxBadFCS=2241

error	22:31:31.246691-0700	wifid	LQM-WiFi: txRTSFrm=839 txCTSFrm=558 txAllFrm=11997

default	22:31:31.246978-0700	WirelessRadioManagerd	\<private>

default	22:31:31.246989-0700	WirelessRadioManagerd	\<private>

default	22:31:31.246995-0700	WirelessRadioManagerd	\<private>

default	22:31:31.247009-0700	WirelessRadioManagerd	\<private>

error	22:31:31.247016-0700	wifid	LQM-WiFi: rxBeaconMbss=42 rxDataUcastMbss=523 rxCNTRLUcast=0 txBACK=0 rxDataMcast=59, rxMgmtMcast=0

error	22:31:31.247333-0700	wifid	LQM-WiFi: rxMpduInAmpdu=577 rxholes=0 rxPER=0 rxdup=5 rxaddbareq=0 txaddbaresp=0 txdelba=0 rxdelba=0

error	22:31:31.247354-0700	wifid	LQM-WiFi: WME RX MSDUs in tids 0:760, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0

error	22:31:31.247387-0700	wifid	LQM-WiFi: BTCoexExtStats1: bt\_gnt\_dur=0 \[us] btc\_status=0x2 bt\_req\_type\_map=0x0 bt\_req\_cnt=5274 bt\_prempt\_cnt=0 bt\_grant\_cnt=0

default	22:31:31.247421-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

error	22:31:31.247441-0700	wifid	LQM-WiFi: BTCoexExtStats2: wlan\_tx\_denial\_cnt = 0 wlan\_rx\_denial\_cnt = 0 bt\_SCO\_rw\_gnt\_cnt = 0 bt\_SCO\_rs\_gnt\_cnt = 0 bt\_SCO\_rw\_deny\_cnt = 0 bt\_SCO\_rs\_deny\_cnt = 0 max\_sco\_consecutive\_deny\_cnt = 0

error	22:31:31.247459-0700	wifid	LQM-WiFi: rxMulti=0 rxUndec=0

default	22:31:31.247472-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

error	22:31:31.248184-0700	wifid	LQM-WiFi: BTCoexExtStats3: bt\_a2dp\_gnt\_cnt = 0 bt\_a2dp\_deny\_cnt = 0 bt\_crtpri\_grant\_cnt = 0 wifi\_tx\_denial\_lt5ms = 0 wifi\_tx\_denial\_lt30ms = 0, wifi\_tx\_denial\_lt60ms = 0, wifi\_tx\_denial\_ge60ms = 0

error	22:31:31.248229-0700	wifid	LQM-WiFi: TX(00:00:00:00:00:00) AC\<SU MS NB NRS NA CM EX TF FFP MRET FLE> BE<8283 0 0 0 0 0 0 0 0 0 0> (5001ms)

default	22:31:31.248243-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

error	22:31:31.248255-0700	wifid	LQM-WiFi: TX(00:00:00:00:00:00) AC\<SU MS NB NRS NA CM EX TF FFP MRET FLE> BK<2 0 0 0 0 0 0 0 0 0 0> (5001ms)

error	22:31:31.248277-0700	wifid	LQM-WiFi: TX(00:00:00:00:00:00) AC\<SU MS NB NRS NA CM EX TF FFP MRET FLE> VI<0 0 0 0 0 0 0 0 0 0 0> (5001ms)

error	22:31:31.248306-0700	wifid	LQM-WiFi: TX(00:00:00:00:00:00) AC\<SU MS NB NRS NA CM EX TF FFP MRET FLE> VO<5 0 0 0 0 0 0 0 0 0 0> (5001ms)

error	22:31:31.248325-0700	wifid	LQM-WiFi: L3 Control VO TX(00:00:00:00:00:00) Success=0 NoACK=0 Expired=0 OtherErr=0

default	22:31:31.248389-0700	wifid	WiFiDeviceManagerGetAppState: app state for DPS action : Foreground isAnyAppInFG:yes isFTactive:no isLatencySensitiveAppActive:no

default	22:31:31.248403-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

default	22:31:31.248416-0700	wifid	RSSI\_WIN: Beacon PER is consistenyly below < 20Percent. Switch to default RSSI Window

default	22:31:31.248440-0700	wifid	-\[WiFiUsageSessionLQM updateAverageOf:with:forSession:] - Unexpected: we don't know how to average for sessionType:10

error	22:31:31.248459-0700	wifid	\_\_WiFiLQAMgrCheckForPossibleRoam waitForRoam: 1, plausibleRoamCandidateFound: 0, lastScanAge: 21.96, largeNetworkEnvironment: 0, isRealTimeApplication: 0, isEdgeBss: 1

default	22:31:31.248480-0700	wifid	\_\_WiFiLQAMgrFetchSymptomsViewOfLink Symptom's view of the link query completed

default	22:31:31.248492-0700	wifid	WiFiLQAMgrCopyCoalescedUndispatchedLQMEvent: Rssi: -68 Snr:26 Cca: 35 TxFrames: 9642 TxFail: 0 BcnRx: 42 BcnSch: 42  RxFrames: 598 RxRetries: 0 TxRate: 288235 RxRate: 648529 FBRate: 144117 TxFwFrms: 18 TxFwFail:0 TxRetries: 2545

default	22:31:31.248667-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : BSS List info for network : jff : chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.248680-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment for network : jff : bssCount: \[3] chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.248739-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment is Multi AP for jff(90:d0:92:4a:9c:d8). Last applied environment is Multi AP. Early exit ? : \[1]. augmented from scan results ? : \[1]

default	22:31:31.249289-0700	WirelessRadioManagerd	\<private>

default	22:31:31.249317-0700	wifid	Copy current network requested by "WirelessRadioManagerd"

default	22:31:31.249381-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : BSS List info for network : jff : chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.249388-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment for network : jff : bssCount: \[3] chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.249397-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment is Multi AP for jff(90:d0:92:4a:9c:d8). Last applied environment is Multi AP. Early exit ? : \[1]. augmented from scan results ? : \[1]

default	22:31:31.249490-0700	wifid	\[corewifi] BEGIN REQ \[GET INTF NAME] (pid=44880 proc=symptomsd bundleID=com.apple.symptomsd codesignID=com.apple.symptomsd service=com.apple.private.corewifi-xpc qos=17 intf=(null) uuid=DEBB4 info=(null))

default	22:31:31.249500-0700	wifid	\[corewifi] \[DEBB4] Incoming QoS is less than 'default', promoting to 'default'

default	22:31:31.249963-0700	wifid	\[corewifi] END REQ \[GET INTF NAME] took 0.000447458s (pid=44880 proc=symptomsd bundleID=com.apple.symptomsd codesignID=com.apple.symptomsd service=com.apple.private.corewifi-xpc qos=21 intf=(null) uuid=DEBB4 err=0 reply=\<redacted>

default	22:31:31.250296-0700	symptomsd	L2 Metrics on en0: rssi: -68 \[-69,-71] -> -68, snr: 26 (cca \[wake/total] self/other/intf): \[20,17]/\[21,18]/\[0,0]/35 (txFrames/txReTx/txFail): 9642/2545/0 -> (was/is) 0/0, txRate: 288.0, rxRate: 648.0, rssiEMA: -67.6, snrEMA: 26.5, txRateEMA: 256.7, rxRateEMA: 506.6, isPrimary: 1, radio: 802.11ax

default	22:31:31.250546-0700	wifid	Copy current network requested by "WirelessRadioManagerd"

default	22:31:31.250679-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : BSS List info for network : jff : chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.250689-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment for network : jff : bssCount: \[3] chanCount5GHz: \[2] chanCount24GHz: \[1] chanCount6GHz: \[0]

default	22:31:31.250695-0700	wifid	\_\_WiFiDeviceManagerEvaluateAPEnvironment: WiFiRoam : AP environment is Multi AP for jff(90:d0:92:4a:9c:d8). Last applied environment is Multi AP. Early exit ? : \[1]. augmented from scan results ? : \[1]

default	22:31:31.251813-0700	WirelessRadioManagerd	\<private>

default	22:31:31.251820-0700	WirelessRadioManagerd	\<private>

default	22:31:31.251876-0700	WirelessRadioManagerd	\<private>

default	22:31:31.251885-0700	WirelessRadioManagerd	\<private>

default	22:31:31.251920-0700	WirelessRadioManagerd	\<private>

default	22:31:31.251938-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252018-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252053-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252060-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252126-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252161-0700	WirelessRadioManagerd	\<private>

default	22:31:31.252167-0700	WirelessRadioManagerd	\<private>

default	22:31:31.253583-0700	backboardd	SyncDBV Transaction | ID=3141616 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.591 | DynamicSlider.Cap=380.591 | Brightness.Limit=380.591 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.297 | IndicatorBrightness.Cap=380.591 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.271399-0700	backboardd	SyncDBV Transaction | ID=3141617 | SDR.Nits=17.927 | Applied.Compensation=1.800 | Nits.Cap=380.542 | DynamicSlider.Cap=380.542 | Brightness.Limit=380.542 | Trusted.Lux=12.510 | HDR.Nits=17.927 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.297 | IndicatorBrightness.Cap=380.542 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.274142-0700	symptomsd	Can't lookup UUID 3C41681F-6C37-3390-976D-356A2AF502AC for procname diagnosticd, coalition (null) nehelper (null)

default	22:31:31.275954-0700	symptomsd	Data Usage for diagnosticd on flow 257642 - WiFi in/out: 25635/1332034091, WiFi delta\_in/delta\_out: 885/13704235, Cell in/out: 0/0, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 4.735

default	22:31:31.276407-0700	symptomsd	Data Usage for companion\_proxy on flow 257626 - WiFi in/out: 189850904/128831951, WiFi delta\_in/delta\_out: 300/0, Cell in/out: 0/0, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 7.076

default	22:31:31.286151-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 6F42218C-19D0-4DEE-B911-D70310EF9FA8

default	22:31:31.286243-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.288149-0700	backboardd	SyncDBV Transaction | ID=3141618 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.492 | DynamicSlider.Cap=380.492 | Brightness.Limit=380.492 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.492 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.288378-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.288489-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 6F42218C-19D0-4DEE-B911-D70310EF9FA8 for XPC participant content source \<private>

default	22:31:31.288508-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.288536-0700	Even Companion	Cancelling watchdog

default	22:31:31.295797-0700	symptomsd	Data Usage for remotepairingdeviced on flow 257250 - WiFi in/out: 27037822296/17802307134, WiFi delta\_in/delta\_out: 138329/15230267, Cell in/out: 0/0, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 7.776

default	22:31:31.297461-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.298026-0700	symptomsd	Data Usage for com.artjiang.helix on flow 256095 - WiFi in/out: 66858935/688468097, WiFi delta\_in/delta\_out: 5004/79793, Cell in/out: 653903/1970398, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 89.158

default	22:31:31.299079-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.299257-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.299880-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.301178-0700	symptomsd	Data Usage for heartbeatd on flow 159869 - WiFi in/out: 183605745/210840960, WiFi delta\_in/delta\_out: 324/409, Cell in/out: 0/0, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 15795.726

default	22:31:31.302963-0700	kernel	\[1032217.179305]: vm: segments queued for swapout: 0 regular, 5735 freezer, 0 donate, 0 ripe, 0 darwkwake, 5735 totalvm: segments queued for swapout: 0 regular, 5000 freezer, 0 donate, 0 ripe, 0 darwkwake, 5000 totalvm: segments queued for swapout: 0 regular, 4863 freezer, 0 donate, 0 ripe, 0 darwkwake, 4863 totalvm: segments queued for swapout: 0 regular, 4364 freezer, 0 donate, 0 ripe, 0 darwkwake, 4364 tota

error	22:31:31.302974-0700	kernel	log,552E9358-8DE4-30D7-B786-D73DDE43F46D,105e7c0

default	22:31:31.305588-0700	backboardd	SyncDBV Transaction | ID=3141619 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.444 | DynamicSlider.Cap=380.444 | Brightness.Limit=380.444 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.444 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.307631-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.308074-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.308327-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.308604-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.308875-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

error	22:31:31.309370-0700	symptomsd	Don't have a tracker for this flow's interface type: 0

default	22:31:31.310260-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.310585-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.310849-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

default	22:31:31.311220-0700	symptomsd	FlowSnapshot: \<private>, waiting to process domain info until flow closing with nil fuuid

error	22:31:31.314964-0700	symptomsd	Don't have a tracker for this flow's interface type: 0

error	22:31:31.315062-0700	symptomsd	Don't have a tracker for this flow's interface type: 0

default	22:31:31.315464-0700	symptomsd	Data Usage for com.apple.datausage.dns.multicast (delegation: mDNSResponder) on flow 129 - WiFi in/out: 37192411/1035689, WiFi delta\_in/delta\_out: 2075/1312, Cell in/out: 0/2, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 366075.291

default	22:31:31.315711-0700	symptomsd	Data Usage for com.apple.datausage.dns.multicast (delegation: mDNSResponder) on flow 128 - WiFi in/out: 37193321/1035689, WiFi delta\_in/delta\_out: 910/0, Cell in/out: 0/2, Cell delta\_in/delta\_out: 0/0, RNF: 0, subscriber tag: 1, total duration: 366075.291

default	22:31:31.318084-0700	symptomsd	Data Stall score: 50

default	22:31:31.318110-0700	symptomsd	Policy denial score: 0.000000

default	22:31:31.318139-0700	symptomsd	More info Foreground app \<present>  interval 21.325084 flows 1 (total 100)

default	22:31:31.318151-0700	symptomsd	Also flags 25  count 1  details Foreground app \<present>  interval 21.325084 flows 1 (total 100)

default	22:31:31.318574-0700	wifid	\_\_WiFiLQAMgrFetchSymptomsViewOfLink\_block\_invoke Processing SYMPTOMS\_INFO\_TRIGGER\_DISCONNECT\_STATE

default	22:31:31.319932-0700	backboardd	SyncDBV Transaction | ID=3141620 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.395 | DynamicSlider.Cap=380.395 | Brightness.Limit=380.395 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.395 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.336585-0700	backboardd	SyncDBV Transaction | ID=3141621 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.347 | DynamicSlider.Cap=380.347 | Brightness.Limit=380.347 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.347 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.337136-0700	kernel	vm: segments queued for swapout: 0 regular, 4133 freezer, 0 donate, 0 ripe, 0 darwkwake, 4133 totalvm: segments queued for swapout: 0 regular, 4034 freezer, 0 donate, 0 ripe, 0 darwkwake, 4034 totalvm: segments queued for swapout: 0 regular, 3528 freezer, 0 donate, 0 ripe, 0 darwkwake, 3528 totalvm: segments queued for swapout: 0 regular, 5290 freezer, 0 donate, 0 ripe, 0 darwkwake, 5290 totalvm: segments queued for swapout: 0 regular, 5417 freezer, 0 donate, 0 ripe, 0 darwkwake, 5417 totalvm: segments queued for swapout: 0 regular, 4855 freezer, 0 donate, 0 ripe, 0 darwkwake, 4855 totalvm: segments queued for swapout: 0 regular, 4665 freezer, 0 donate, 0 ripe, 0 darwkwake, 4665 totalvm: segments queued for swapout: 0 regular, 6555 freezer, 0 donate, 0 ripe, 0 darwkwake, 6555 tota

default	22:31:31.337153-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.337162-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.337424-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.345609-0700	WirelessRadioManagerd	\<private>

default	22:31:31.347327-0700	kernel	wlan0:com.apple.p2p.en0:   set Datapath Open needsTrigger 0

default	22:31:31.353844-0700	backboardd	SyncDBV Transaction | ID=3141622 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.299 | DynamicSlider.Cap=380.299 | Brightness.Limit=380.299 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.299 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.371860-0700	backboardd	SyncDBV Transaction | ID=3141623 | SDR.Nits=17.926 | Applied.Compensation=1.800 | Nits.Cap=380.251 | DynamicSlider.Cap=380.251 | Brightness.Limit=380.251 | Trusted.Lux=12.510 | HDR.Nits=17.926 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.295 | IndicatorBrightness.Cap=380.251 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.389233-0700	audiomxd	     HALS\_IOStreamDSP.cpp:631    getting parameter \<private>

default	22:31:31.389429-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: D7D24E67-D49C-46E9-8DCA-2AE25EB5FBC4

default	22:31:31.389455-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.389792-0700	audiomxd	     HALS\_IOStreamDSP.cpp:631    getting parameter \<private>

default	22:31:31.390353-0700	backboardd	SyncDBV Transaction | ID=3141624 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.202 | DynamicSlider.Cap=380.202 | Brightness.Limit=380.202 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.202 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.390384-0700	audiomxd	     HALS\_IOStreamDSP.cpp:631    getting parameter \<private>

default	22:31:31.390703-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.390860-0700	audiomxd	     HALS\_IOStreamDSP.cpp:631    getting parameter \<private>

default	22:31:31.390877-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload D7D24E67-D49C-46E9-8DCA-2AE25EB5FBC4 for XPC participant content source \<private>

default	22:31:31.390918-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.390965-0700	Even Companion	Cancelling watchdog

default	22:31:31.407922-0700	backboardd	SyncDBV Transaction | ID=3141625 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.157 | DynamicSlider.Cap=380.157 | Brightness.Limit=380.157 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.157 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.421737-0700	backboardd	SyncDBV Transaction | ID=3141626 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.111 | DynamicSlider.Cap=380.111 | Brightness.Limit=380.111 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.111 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.428709-0700	backboardd	\[ALS] ts=933228.531 lux=11.414\<private> xy=(0.448 0.396) chs=\[126 211 452 848 1285] CCT1=3102.252 gain=512x mode=\<private> subsamples=120 rawLux=11.462 nits=50 xTalk=\[0 0 2 2 2] status=0x0B copyEvent=0

default	22:31:31.430202-0700	backboardd	ScheduleSetBrightnessIn\_block\_invoke: enter WaitUntil late 0.023667 millisecond (1151441 / 1151441)

default	22:31:31.430716-0700	backboardd	SyncDBV Transaction | ID=3141627 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.111 | DynamicSlider.Cap=380.111 | Brightness.Limit=380.111 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.111 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.432440-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.432452-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.432487-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.437383-0700	backboardd	SyncDBV Transaction | ID=3141628 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.064 | DynamicSlider.Cap=380.064 | Brightness.Limit=380.064 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.064 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.454581-0700	backboardd	SyncDBV Transaction | ID=3141629 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=380.018 | DynamicSlider.Cap=380.018 | Brightness.Limit=380.018 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.292 | IndicatorBrightness.Cap=380.018 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.467149-0700	Even Companion	\<private>

default	22:31:31.467253-0700	Even Companion	\<private>

default	22:31:31.468019-0700	Even Companion	\<private>

default	22:31:31.468105-0700	Even Companion	\<private>

default	22:31:31.471890-0700	backboardd	SyncDBV Transaction | ID=3141630 | SDR.Nits=17.925 | Applied.Compensation=1.800 | Nits.Cap=379.973 | DynamicSlider.Cap=379.973 | Brightness.Limit=379.973 | Trusted.Lux=12.510 | HDR.Nits=17.925 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.290 | IndicatorBrightness.Cap=379.973 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.485574-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: A7257CA4-47F3-42F0-81F7-4CE6D439FF72

default	22:31:31.487962-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.489613-0700	backboardd	SyncDBV Transaction | ID=3141631 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.928 | DynamicSlider.Cap=379.928 | Brightness.Limit=379.928 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.290 | IndicatorBrightness.Cap=379.928 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.489784-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.489793-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload A7257CA4-47F3-42F0-81F7-4CE6D439FF72 for XPC participant content source \<private>

default	22:31:31.489810-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.489881-0700	Even Companion	Cancelling watchdog

default	22:31:31.506270-0700	backboardd	SyncDBV Transaction | ID=3141632 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.883 | DynamicSlider.Cap=379.883 | Brightness.Limit=379.883 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.290 | IndicatorBrightness.Cap=379.883 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.506958-0700	corespeechd	-\[CSSelfTriggerDetector \_keywordAnalyzerNDAPI:hasResultAvailable:forChannel:] Output NDAPI self trigger best score = -25.386198 for channel = 0, client listening ? NO, audioSourceType 1, threshold = 2.411000

default	22:31:31.521028-0700	backboardd	SyncDBV Transaction | ID=3141633 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.838 | DynamicSlider.Cap=379.838 | Brightness.Limit=379.838 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.290 | IndicatorBrightness.Cap=379.838 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.537786-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.537797-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.537976-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.538338-0700	backboardd	SyncDBV Transaction | ID=3141634 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.794 | DynamicSlider.Cap=379.794 | Brightness.Limit=379.794 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.290 | IndicatorBrightness.Cap=379.794 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.554354-0700	backboardd	SyncDBV Transaction | ID=3141635 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.750 | DynamicSlider.Cap=379.750 | Brightness.Limit=379.750 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.288 | IndicatorBrightness.Cap=379.750 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.571206-0700	backboardd	SyncDBV Transaction | ID=3141636 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.706 | DynamicSlider.Cap=379.706 | Brightness.Limit=379.706 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.288 | IndicatorBrightness.Cap=379.706 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.589060-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: 84F3C0CD-1DAF-4319-97D3-FC5B247A0556

default	22:31:31.589081-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.590006-0700	backboardd	SyncDBV Transaction | ID=3141637 | SDR.Nits=17.924 | Applied.Compensation=1.800 | Nits.Cap=379.663 | DynamicSlider.Cap=379.663 | Brightness.Limit=379.663 | Trusted.Lux=12.510 | HDR.Nits=17.924 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.288 | IndicatorBrightness.Cap=379.663 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.590332-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.590346-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload 84F3C0CD-1DAF-4319-97D3-FC5B247A0556 for XPC participant content source \<private>

default	22:31:31.590374-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.590421-0700	Even Companion	Cancelling watchdog

default	22:31:31.606858-0700	backboardd	SyncDBV Transaction | ID=3141638 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.620 | DynamicSlider.Cap=379.620 | Brightness.Limit=379.620 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.288 | IndicatorBrightness.Cap=379.620 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.621360-0700	backboardd	SyncDBV Transaction | ID=3141639 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.577 | DynamicSlider.Cap=379.577 | Brightness.Limit=379.577 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.288 | IndicatorBrightness.Cap=379.577 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.637761-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.637773-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.637803-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.637887-0700	backboardd	SyncDBV Transaction | ID=3141640 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.535 | DynamicSlider.Cap=379.535 | Brightness.Limit=379.535 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.535 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.654169-0700	backboardd	SyncDBV Transaction | ID=3141641 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.493 | DynamicSlider.Cap=379.493 | Brightness.Limit=379.493 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.493 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.671962-0700	backboardd	SyncDBV Transaction | ID=3141642 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.451 | DynamicSlider.Cap=379.451 | Brightness.Limit=379.451 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.451 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.681706-0700	backboardd	\[ALS] ts=933228.785 lux=11.389\<private> xy=(0.457 0.408) chs=\[104 214 450 844 1294] CCT1=3015.354 gain=512x mode=\<private> subsamples=120 rawLux=11.460 nits=50 xTalk=\[0 0 3 3 3] status=0x0B copyEvent=0

default	22:31:31.682730-0700	backboardd	ScheduleSetBrightnessIn\_block\_invoke: enter WaitUntil late 0.027708 millisecond (1151442 / 1151442)

default	22:31:31.683531-0700	backboardd	SyncDBV Transaction | ID=3141643 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.451 | DynamicSlider.Cap=379.451 | Brightness.Limit=379.451 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.451 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.688988-0700	Even Companion	Updating activity: 6CD761DF-1A26-4589-BAA9-55654DC49CD7; payload: CE8F9650-53A9-40A5-B3F7-C138305B9928

default	22:31:31.688999-0700	Even Companion	Watchdog will fire in 10.000000s

default	22:31:31.689857-0700	backboardd	SyncDBV Transaction | ID=3141644 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.406 | DynamicSlider.Cap=379.406 | Brightness.Limit=379.406 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.406 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.690265-0700	liveactivitiesd	Foreground process is permitted to update activity: 47488

default	22:31:31.690279-0700	liveactivitiesd	Pending activity update for 6CD761DF-1A26-4589-BAA9-55654DC49CD7 with payload CE8F9650-53A9-40A5-B3F7-C138305B9928 for XPC participant content source \<private>

default	22:31:31.690306-0700	liveactivitiesd	Activity continues to be chatty: 6CD761DF-1A26-4589-BAA9-55654DC49CD7

default	22:31:31.690330-0700	Even Companion	Cancelling watchdog

default	22:31:31.705792-0700	backboardd	SyncDBV Transaction | ID=3141645 | SDR.Nits=17.923 | Applied.Compensation=1.800 | Nits.Cap=379.369 | DynamicSlider.Cap=379.369 | Brightness.Limit=379.369 | Trusted.Lux=12.510 | HDR.Nits=17.923 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.369 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.721633-0700	backboardd	SyncDBV Transaction | ID=3141646 | SDR.Nits=17.922 | Applied.Compensation=1.800 | Nits.Cap=379.328 | DynamicSlider.Cap=379.328 | Brightness.Limit=379.328 | Trusted.Lux=12.510 | HDR.Nits=17.922 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.286 | IndicatorBrightness.Cap=379.328 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.737106-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.737164-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.737435-0700	kernel	ANE0: aneFirmwareCommandSend: Skip waiting for response

default	22:31:31.737771-0700	backboardd	SyncDBV Transaction | ID=3141647 | SDR.Nits=17.922 | Applied.Compensation=1.800 | Nits.Cap=379.288 | DynamicSlider.Cap=379.288 | Brightness.Limit=379.288 | Trusted.Lux=12.510 | HDR.Nits=17.922 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.284 | IndicatorBrightness.Cap=379.288 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.740200-0700	kernel	wlan0:com.apple.p2p.awdl0: setSyncFramePeriod:25952 +++ Configuring the sync params(period, length) {16 16}, extlen = 16

default	22:31:31.740226-0700	kernel	wlan0:com.apple.p2p.awdl0: setSyncFramePeriod::Setting PSF period to 110

default	22:31:31.740247-0700	kernel	wlan0:com.apple.p2p.awdl0: programChipWithNewMaster: Programming new Mst: EA:B7:DF:E4:63:DB at 933228.855ms HC 1 met 534 my met 522

default	22:31:31.740262-0700	kernel	wlan0:com.apple.p2p.awdl0: setSyncFramePeriod:25952 +++ Configuring the sync params(period, length) {16 16}, extlen = 16

default	22:31:31.740272-0700	kernel	wlan0:com.apple.p2p.awdl0: setSyncFramePeriod::Setting PSF period to 110

default	22:31:31.740287-0700	kernel	wlan0:com.apple.p2p.awdl0: runElection: ElectionParamsChanged - Prog (F:1, 0) New P:EA:B7:DF:E4:63:DB R:EA:B7:DF:E4:63:DB \[RLFC:786979 HC:1 RMet:534 SLFC:2095 SMet:522]

default	22:31:31.740305-0700	kernel	wlan0:com.apple.p2p.en0:   set Datapath Open needsTrigger 0

error	22:31:31.744666-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.754815-0700	backboardd	SyncDBV Transaction | ID=3141648 | SDR.Nits=17.922 | Applied.Compensation=1.800 | Nits.Cap=379.247 | DynamicSlider.Cap=379.247 | Brightness.Limit=379.247 | Trusted.Lux=12.510 | HDR.Nits=17.922 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.284 | IndicatorBrightness.Cap=379.247 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

default	22:31:31.758654-0700	locationd	{"msg":"onAvengerAdvertisementDetected convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"ADLAvenger"}

default	22:31:31.758707-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"ADLAvenger"}

default	22:31:31.758809-0700	locationd	{"msg":"onAvengerAdvertisementDetected: got avenger advertisement", "subHarvester":"Avenger"}

default	22:31:31.758858-0700	locationd	\<private>

default	22:31:31.758878-0700	locationd	{"msg":"convertToSPAdvertisement", "address":\<private>, "data":\<private>, "date":\<private>, "rssi":\<private>, "status":\<private>, "reserved":\<private>, "subHarvester":"Avenger"}

default	22:31:31.758915-0700	locationd	{"msg":"onAvengerAdvertisementDetected: advertisement is near-owner from other people and do not process it", "subHarvester":"Avenger"}

error	22:31:31.764652-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

default	22:31:31.771775-0700	backboardd	SyncDBV Transaction | ID=3141649 | SDR.Nits=17.922 | Applied.Compensation=1.800 | Nits.Cap=379.207 | DynamicSlider.Cap=379.207 | Brightness.Limit=379.207 | Trusted.Lux=12.510 | HDR.Nits=17.922 | HDR.State=Off | Capped.Headroom.Current=1.000  | Aurora.Factor=1.000 | Aurora.RampInProgress=NO | RTPLC.State=None | RTPLC.Cap=1600.000 | RTPLC.CapApplied=NO | PeakAPCE.Cap=0.010 | IndicatorBrightness.Nits=50.284 | IndicatorBrightness.Cap=379.207 | Twilight.Strength=0.000 | Ammolite.Strength=0.000 | GCP.Strength=0.860 | ContrastEnhancer.Strength=0.000 |

error	22:31:31.784498-0700	audiomxd	VirtualAudioDevice\_Default: IOProc expected 1120, got 960 frames

error	22:31:31.786470-0700	kernel	log,552E9358-8DE4-30D7-B786-D73DDE43F46D,105e7c0

---

## 2. Live Activity buttons visible on answer — CRITICAL (Plan C regression)

**Previous symptom:** Once `context.state.answer` populated, Ask/Pause/Resume button row disappeared from both Lock Screen and Dynamic Island (buttons pushed off-screen by long answers). Fixed on C branch by `3b3924d` (2-line cap + tail truncation).

### Lock Screen

- Start a live listening session, lock the phone
- Verify Live Activity appears with status + Ask/Pause buttons visible
- Trigger a question with a LONG answer (e.g. "Explain how TCP congestion control works")
- **While the answer streams on Lock Screen**, verify:
  - Answer text shows (truncated to 2 lines with `…` tail)
  - Ask button still visible below the answer
  - Pause/Resume button still visible
- Tap Pause button → transcription pauses (status updates)
- Tap Resume → transcription resumes
- Tap Ask → manual Q\&A triggers

### Dynamic Island

- Unlock phone, keep session running
- Long-press Dynamic Island to expand
- Trigger another long answer
- **While answer streams in expanded Dynamic Island**, verify:
  - Answer text shows (capped 2 lines)
  - Button row still visible below

---

## 3. HUD flashing during streaming (dashboard race) — cherry-picked from Plan A

**Previous symptom:** Glasses HUD flashed between dashboard "REC HH:MM" text and AI answer during streaming because `DashboardService._refreshDashboardIfActive` was pushing a dashboard frame on the same `0x4e/0x71` channel while the LLM streamed to `0x4e/0x30/0x31`. Fix: suppress dashboard refresh when `EngineStatus` is `thinking` or `responding`.

- Start a live listening session (dashboard visible on glasses when idle)
- Trigger a question
- Watch glasses during the full AI response window (\~3-10 seconds)
- Verify:
  - **No flashing between dashboard and answer**
  - Answer stays on screen continuously from first token to last
  - No "REC HH:MM" or date text briefly flashing in
- After answer completes + idle for 60s, dashboard refresh resumes normally (expected)

---

## 4. Transcription drops 3-5s on Q\&A press — cherry-picked from Plan A

**Previous symptom:** `_runManualContextualQa` called `pauseTranscription()` for the entire LLM call duration, dropping anything the user said in that window. Fix: removed the pause/resume entirely.

- Start a live listening session
- Begin speaking a continuous sentence ("I want to ask about... the history of the Roman Empire and specifically...")
- **Mid-sentence, press the Q\&A button** (right touchpad or in-app Ask button)
- Continue speaking ("...how it collapsed in the west")
- Verify:
  - The full sentence (including the words spoken during/after the Q\&A press) appears in the transcript
  - No \~3-5 second gap in the transcript around the Q\&A press
  - AI answer is generated based on the context

---

## 5. Scroll-up during streaming — cherry-picked from Plan A

**Previous symptom:** `HomeScreen._scrollToBottom` was unconditional, yanking the transcript back to bottom on every \~50ms streaming update. Fix: 64px tolerance — skip auto-scroll if user has scrolled up.

- Start a live listening session, accumulate some transcript
- Trigger a long-answer question
- **While the answer is streaming**, manually scroll UP on the home screen transcript
- Verify:
  - Transcript stays where you scrolled (does NOT snap back to bottom every 50ms)
  - Can read earlier transcript comfortably
- Scroll back down to the bottom manually
- Verify auto-scroll re-engages (new content re-snaps to bottom once you're within 64px)

---

## 6. Q\&A "Assistant Request failed" — DIAGNOSTIC CAPTURE

**Previous symptom:** Pressing Q\&A on a live session sometimes produced "Assistant Request failed" / "The response could not be generated" — the generic unknown-bucket fallback in `ProviderErrorState.fromException`. No prior fix exists. This build adds diagnostic logging to capture the raw upstream error.

### If you can repro the failure:

- Open Xcode device console OR `Console.app` filtered to Helix/Even Companion
- Add filter: `ProviderErrorState` OR `_generateResponse received`
- Trigger the failing Q\&A flow (whatever sequence causes it — try both verbal questions and manual button presses with short/long transcripts)
- When the error shows on phone/glasses, look for these lines in the console:
- **Copy the full raw error text from both lines and paste into next Claude session.** That's exactly what I need to map it to a pattern or root-cause fix in the provider layer.

### If you cannot repro:

- Try several Q\&A presses in different states:
  - Fresh session, no prior transcript
  - Mid-session, long transcript window
  - After a prior AI answer has completed
  - While an AI answer is still streaming (should be rejected or queued)
  - Quickly pressed twice in succession
- If stable across all of the above, the bug may be intermittent — note it and move on. The diagnostic logging stays in place for next repro.

---

## 7. B — HUD line streaming flag (OFF by default, optional test)

**New feature:** `HudStreamSession` routes streaming HUD text behind a `hud.lineStreaming` settings flag (default OFF). When OFF, the legacy full-canvas path runs unchanged. When ON, line-gated streaming emits on line boundaries instead of every token.

### Default (flag OFF) — should be unchanged from pre-B behavior

- Confirm Settings does NOT show `hud.lineStreaming` enabled (or it reads "Off")
- Trigger a streaming answer
- Verify glasses show the same token-by-token full-canvas updates as always
- Jitter/flicker level is same as before (left-eye fix + dashboard-race fix means less flashing overall, but no new jitter introduced by B)

### Optional: flag ON

- Enable `hud.lineStreaming` in Settings (wherever the dev toggle lives — may need to search)
- Trigger a long-answer question
- Verify:
  - HUD updates come in on line boundaries (not every token)
  - Text grows monotonically (never shrinks or flickers backwards)
  - Final frame matches the phone-side text exactly
- Turn flag OFF again and confirm legacy path still works

---

## 8. D — Session cost tracking (new feature)

**New feature:** Cumulative session cost tracking for smart/light/transcription models. Badge on Home, detail breakdown sheet, per-conversation cost in History.

- Home screen shows a **session cost badge** somewhere visible (may be in header/footer)
- Badge starts at $0.00 on fresh session
- Trigger a few questions in the session
- Verify badge increments after each AI response
- Tap the badge → **cost breakdown sheet** opens showing:
  - Smart model cost
  - Light model cost (if any)
  - Transcription cost
  - Total
- Open History tab → find the current session
- Verify history row shows the cost
- Create a second session → its badge starts at $0.00 (not cumulative across sessions)

---

## 9. Regression spot-checks

Stuff that should still work — quick verification nothing else broke:

- BLE connection survives lock/unlock
- Mic permission prompt (only on first recording, not launch)
- Touchpad events — notifyIndex 23/24 start/stop listening
- Text query flow (Home → type question → answer)
- Settings persistence across app restart

---

## What to report back

If everything passes: "all green, ready to push"
If something fails: paste the failing checklist item + any console logs + screenshot/video if visual

**Specifically for the Q\&A failure (item 6)**, even if it works this time, leave the diagnostic logging in place — we'll remove it in a follow-up commit once we're sure the bug is gone.

---

## Deferred this session (NOT to test)

These are logged and waiting, don't flag them as bugs:

- Plan A (priority-pipeline) — paused mid Phase 1a
- Tier-1 TODOs: Summarize/Rephrase/Translate/FactCheck, Follow-up deck send, Live Page blank
- Plan D shim cleanup (7 sites marked `TODO(plan-A)`)
