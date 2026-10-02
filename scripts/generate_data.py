"""
Generate fake commerce data for the Commerce Intelligence Mini project.

Structured:   customers, products, orders, order_lines, order_events  (CSV)
Unstructured: support_cases                                           (newline-delimited JSON)
Evaluation:   case_labels  (the "human-labeled sample" used to measure AI accuracy)

Two batches are produced so incremental models can be exercised:
  batch_1  initial load (orders from 2026-07-01 to 2026-09-15)
  batch_2  new orders, status UPDATES to existing orders, LATE-ARRIVING orders,
           customer segment changes (for the SCD2 snapshot), more events and cases

Output layout mirrors the S3 layout:  data/batch_N/<entity>/<entity>_batch_N.<ext>
Upload one batch at a time:           aws s3 cp data/batch_1/ s3://commerce-ai-raw/ --recursive

Standard library only. Deterministic (seeded), so reruns produce identical files.
"""

import csv
import json
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)
OUT = Path(__file__).resolve().parent.parent / "data"

REGIONS = {
    "AMER": ["United States", "Canada", "Brazil", "Mexico"],
    "EMEA": ["Germany", "United Kingdom", "Spain", "France"],
    "APJ": ["India", "Japan", "Australia", "Singapore"],
}
SEGMENTS = ["SMB", "Mid-Market", "Enterprise"]
CURRENCY = {"AMER": "USD", "EMEA": "EUR", "APJ": "USD"}

# Invented product catalog (no real product names)
PRODUCTS_BY_FAMILY = {
    "Networking": ["EdgeSwitch 24", "EdgeSwitch 48", "CoreRouter 400", "CoreRouter 800",
                   "AirPoint AP6", "AirPoint AP7", "MeshLink Controller", "FiberHub 10G",
                   "BranchRouter 120", "CampusSwitch 96"],
    "Security": ["ShieldWall 200", "ShieldWall 900", "ZeroTrust Gateway", "SecureVPN Client",
                 "ThreatScan Cloud", "IdentityGuard", "MailShield", "DNSProtect",
                 "EndpointSentinel", "SIEM Lite"],
    "Collaboration": ["MeetRoom Bar", "MeetRoom Pro", "DeskPhone 8", "DeskPhone 9",
                      "HeadSet Wireless", "Whiteboard 55", "ContactCenter Suite",
                      "MeetCloud License", "CallingCloud License", "Room Kit Mini"],
    "Cloud": ["Observability Suite", "AppMonitor Lite", "Workload Optimizer", "CloudManage",
              "Hybrid Cloud Pack", "Kubernetes Ops", "Data Fabric Add-on", "API Gateway Pro",
              "Edge Compute Node", "Backup Vault"],
}

COMPANY_A = ["Acme", "Globex", "Initech", "Umbrella", "Stark", "Wayne", "Wonka", "Tyrell",
             "Cyberdyne", "Soylent", "Hooli", "Vandelay", "Pied", "Massive", "Oceanic",
             "Aperture", "Gringotts", "Monarch", "Nakatomi", "Sterling"]
COMPANY_B = ["Logistics", "Retail", "Health", "Finance", "Energy", "Telecom", "Foods",
             "Motors", "Labs", "Systems", "Media", "Airlines", "Bank", "Pharma", "Insurance"]

ORDER_STATUSES_FLOW = ["BOOKED", "SHIPPED", "DELIVERED"]

# --- Support case note templates -------------------------------------------------------
# {oid} = order id, {prod} = product name. Ground-truth issue_type is stored separately.
NOTES = {
    "shipping delay": [
        "Customer reports order {oid} for {prod} has not arrived. It was promised two weeks ago and tracking has not updated in 9 days. They need it for a site launch next Monday.",
        "Partner escalation: shipment for {oid} is stuck in customs. End customer is threatening to cancel the remaining {prod} units if this is not resolved this week.",
        "Order {oid} shows SHIPPED but the carrier says no package was handed over. Customer is frustrated and asking for a firm delivery date for the {prod}.",
        "Delivery of {prod} slipped again. Customer says this is the third reschedule and leadership is asking why the rollout is late.",
    ],
    "pricing or billing": [
        "Customer was invoiced twice for order {oid}. They want the duplicate charge for the {prod} reversed before their month-end close.",
        "Renewal quote for {prod} came in 30 percent higher than last year with no explanation. Customer is asking for the previous discount to be honored.",
        "Invoice for {oid} lists the wrong currency and the totals do not match the approved quote. Finance team cannot process payment.",
        "Partner says the deal registration discount was not applied to {oid}. They are losing margin on the {prod} and want a credit note.",
    ],
    "licensing": [
        "Customer cannot activate the {prod} license from order {oid}. The portal says the entitlement is already assigned to another account.",
        "License keys for {prod} expired early, 2 months before the subscription end date. Users are locked out this morning.",
        "Customer bought 50 seats of {prod} but the admin console only shows 20. Need the remaining entitlements added to the smart account.",
        "Transfer of {prod} licenses between subsidiaries is blocked. Customer needs this done before an audit next week.",
    ],
    "product defect": [
        "Two units of {prod} from order {oid} are rebooting every few hours. Firmware was updated but the problem continues. Requesting RMA.",
        "{prod} arrived with a damaged power supply. Customer sent photos and wants a replacement shipped overnight.",
        "After the latest update the {prod} drops connections under load. This is affecting their call center during peak hours.",
        "Fan noise and overheating reported on {prod}. Customer is worried about hardware failure in their data center.",
    ],
    "installation help": [
        "Customer needs help configuring {prod} for a new branch office. They are asking for a remote session with an engineer this week.",
        "Question about integrating {prod} with their existing directory service. Documentation link was not clear. Polite request, no urgency.",
        "Customer wants best practices for deploying {prod} across 12 sites. Happy with the product so far and planning a larger rollout.",
        "Partner engineer asking for the recommended upgrade path for {prod} before a maintenance window next month.",
    ],
}
NOTES_ES = {
    "shipping delay": "El pedido {oid} con {prod} no ha llegado y el cliente necesita una fecha de entrega confirmada. Esta muy molesto por el retraso.",
    "pricing or billing": "El cliente recibio una factura duplicada por el pedido {oid}. Solicita la anulacion del cargo del {prod}.",
    "licensing": "El cliente no puede activar la licencia de {prod} del pedido {oid}. El portal muestra un error de asignacion.",
    "product defect": "Las unidades de {prod} del pedido {oid} se reinician constantemente. El cliente solicita un reemplazo urgente.",
    "installation help": "El cliente necesita ayuda para configurar {prod} en una nueva oficina. Solicita una sesion remota con un ingeniero.",
}
NOTES_DE = {
    "shipping delay": "Die Bestellung {oid} mit {prod} ist immer noch nicht angekommen. Der Kunde ist veraergert und braucht einen festen Liefertermin.",
    "pricing or billing": "Der Kunde wurde fuer die Bestellung {oid} doppelt belastet und bittet um Gutschrift fuer das {prod}.",
    "licensing": "Der Kunde kann die Lizenz fuer {prod} aus Bestellung {oid} nicht aktivieren. Das Portal meldet einen Fehler.",
    "product defect": "Mehrere {prod} Geraete aus Bestellung {oid} starten staendig neu. Der Kunde fordert dringend Ersatz.",
    "installation help": "Der Kunde benoetigt Unterstuetzung bei der Einrichtung von {prod} in einer neuen Niederlassung.",
}
SUBJECTS = {
    "shipping delay": ["Where is my order", "Delivery delayed", "Shipment status"],
    "pricing or billing": ["Invoice issue", "Billing question", "Quote discrepancy"],
    "licensing": ["License activation", "Entitlement problem", "License question"],
    "product defect": ["Hardware issue", "Device not working", "RMA request"],
    "installation help": ["Setup assistance", "Configuration help", "Deployment question"],
}


def ts(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def rand_dt(start, end):
    span = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, span))


def write_csv(path, rows, header):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=header)
        w.writeheader()
        w.writerows(rows)


def write_ndjson(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------- reference data
products = []
pid = 1
for family, names in PRODUCTS_BY_FAMILY.items():
    for name in names:
        products.append({
            "product_id": f"P{pid:03d}",
            "product_name": name,
            "product_family": family,
            "list_price_cents": random.choice([49900, 129900, 249900, 499900, 899900, 1599900]),
        })
        pid += 1

customers = []
batch1_start = datetime(2026, 7, 1)
for i in range(1, 301):
    region = random.choice(list(REGIONS))
    customers.append({
        "customer_id": f"C{i:04d}",
        "customer_name": f"{random.choice(COMPANY_A)} {random.choice(COMPANY_B)} {i}",
        "region": region,
        "country": random.choice(REGIONS[region]),
        "segment": random.choices(SEGMENTS, weights=[5, 3, 2])[0],
        "updated_at": ts(batch1_start - timedelta(days=random.randint(30, 400))),
    })
cust_by_id = {c["customer_id"]: c for c in customers}
prod_by_id = {p["product_id"]: p for p in products}


# ---------------------------------------------------------------- orders, lines, events
order_seq = 10001
line_seq = 1
event_seq = 1


def make_order(order_date, loaded_at):
    """Create one order with lines and lifecycle events. Returns (order, lines, events)."""
    global order_seq, line_seq, event_seq
    cust = random.choice(customers)
    oid = f"ORD-{order_seq}"
    order_seq += 1

    lines = []
    for _ in range(random.randint(1, 4)):
        p = random.choice(products)
        qty = random.randint(1, 20)
        discount = random.choice([0, 0, 0.05, 0.10, 0.15, 0.25])
        lines.append({
            "order_line_id": f"L{line_seq:06d}",
            "order_id": oid,
            "product_id": p["product_id"],
            "quantity": qty,
            "unit_price_cents": int(p["list_price_cents"] * (1 - discount)),
        })
        line_seq += 1

    # how far the order has progressed by load time
    age_days = (loaded_at - order_date).days
    if random.random() < 0.05:
        status = "CANCELLED"
    elif age_days > 20:
        status = "DELIVERED"
    elif age_days > 7:
        status = "SHIPPED"
    else:
        status = "BOOKED"

    events = []
    flow = ["BOOKED"] if status == "CANCELLED" else ORDER_STATUSES_FLOW[: ORDER_STATUSES_FLOW.index(status) + 1]
    event_time = order_date
    for st in flow:
        events.append({"event_id": f"E{event_seq:07d}", "order_id": oid,
                       "event_type": st, "event_ts": ts(event_time)})
        event_seq += 1
        event_time += timedelta(days=random.randint(3, 10), hours=random.randint(0, 23))
    if status == "CANCELLED":
        events.append({"event_id": f"E{event_seq:07d}", "order_id": oid,
                       "event_type": "CANCELLED", "event_ts": ts(order_date + timedelta(days=2))})
        event_seq += 1

    last_event_ts = max(e["event_ts"] for e in events)
    order = {
        "order_id": oid,
        "customer_id": cust["customer_id"],
        "order_date": order_date.strftime("%Y-%m-%d"),
        "status": status,
        "currency": CURRENCY[cust["region"]],
        "updated_at": min(last_event_ts, ts(loaded_at)),
    }
    return order, lines, events


# batch 1: orders 2026-07-01 .. 2026-09-15, loaded 2026-09-16
b1_loaded = datetime(2026, 9, 16, 2, 0)
b1_orders, b1_lines, b1_events = [], [], []
for _ in range(2000):
    o, l, e = make_order(rand_dt(batch1_start, datetime(2026, 9, 15, 23, 0)), b1_loaded)
    b1_orders.append(o); b1_lines += l; b1_events += e

# batch 2: new orders 2026-09-16 .. 2026-09-30, loaded 2026-10-01
b2_loaded = datetime(2026, 10, 1, 2, 0)
b2_orders, b2_lines, b2_events = [], [], []
for _ in range(400):
    o, l, e = make_order(rand_dt(datetime(2026, 9, 16), datetime(2026, 9, 30, 23, 0)), b2_loaded)
    b2_orders.append(o); b2_lines += l; b2_events += e

# batch 2: LATE-ARRIVING orders (order_date in batch-1 window, but only loaded now)
late_ids = []
for _ in range(25):
    o, l, e = make_order(rand_dt(datetime(2026, 9, 5), datetime(2026, 9, 14)), b2_loaded)
    b2_orders.append(o); b2_lines += l; b2_events += e
    late_ids.append(o["order_id"])

# batch 2: STATUS UPDATES to existing batch-1 orders (same order_id, newer updated_at)
open_b1 = [o for o in b1_orders if o["status"] in ("BOOKED", "SHIPPED")]
for o in random.sample(open_b1, min(150, len(open_b1))):
    new_status = "SHIPPED" if o["status"] == "BOOKED" else "DELIVERED"
    upd_time = datetime(2026, 9, 20) + timedelta(days=random.randint(0, 9), hours=random.randint(0, 23))
    b2_orders.append({**o, "status": new_status, "updated_at": ts(upd_time)})
    b2_events.append({"event_id": f"E{event_seq:07d}", "order_id": o["order_id"],
                      "event_type": new_status, "event_ts": ts(upd_time)})
    event_seq += 1

# batch 2: customer SEGMENT CHANGES (drives the SCD2 snapshot)
b2_customers = []
for c in random.sample(customers, 20):
    new_seg = random.choice([s for s in SEGMENTS if s != c["segment"]])
    b2_customers.append({**c, "segment": new_seg,
                         "updated_at": ts(datetime(2026, 9, 25) + timedelta(hours=random.randint(0, 100)))})
# plus 10 brand-new customers
for i in range(301, 311):
    region = random.choice(list(REGIONS))
    b2_customers.append({
        "customer_id": f"C{i:04d}",
        "customer_name": f"{random.choice(COMPANY_A)} {random.choice(COMPANY_B)} {i}",
        "region": region, "country": random.choice(REGIONS[region]),
        "segment": random.choice(SEGMENTS), "updated_at": ts(datetime(2026, 9, 28)),
    })


# ---------------------------------------------------------------- support cases (unstructured)
case_seq = 50001


def make_cases(order_pool, line_pool, n, start, end):
    """Free-text support cases, ~70% mention an order id. Returns (cases, labels)."""
    global case_seq
    lines_by_order = {}
    for ln in line_pool:
        lines_by_order.setdefault(ln["order_id"], []).append(ln)
    cases, labels = [], []
    for _ in range(n):
        issue = random.choices(list(NOTES), weights=[3, 2, 2, 2, 1])[0]
        o = random.choice(order_pool)
        cust = cust_by_id[o["customer_id"]]
        prod = prod_by_id[random.choice(lines_by_order[o["order_id"]])["product_id"]]["product_name"]
        mentions_order = random.random() < 0.7
        oid_text = o["order_id"] if mentions_order else "their recent order"

        lang = "en"
        if cust["country"] in ("Spain", "Mexico") and random.random() < 0.6:
            lang, text = "es", NOTES_ES[issue]
        elif cust["country"] == "Germany" and random.random() < 0.6:
            lang, text = "de", NOTES_DE[issue]
        else:
            text = random.choice(NOTES[issue])
        notes = text.format(oid=oid_text, prod=prod)

        cid = f"CASE-{case_seq}"
        case_seq += 1
        created = rand_dt(start, end)
        cases.append({
            "case_id": cid,
            "created_at": ts(created),
            "customer_id": cust["customer_id"],
            "channel": random.choice(["email", "portal", "phone", "partner_portal"]),
            "language": lang,
            "case": {                                    # nested object -> VARIANT path notation
                "subject": random.choice(SUBJECTS[issue]),
                "notes": notes,
                "priority": random.choice(["P1", "P2", "P3", "P3", "P4"]),
            },
            "tags": random.sample(["vip", "renewal", "partner", "escalated", "new_customer",  # array -> FLATTEN
                                   "repeat_contact"], k=random.randint(0, 3)),
        })
        labels.append({"case_id": cid, "true_issue_type": issue,
                       "true_order_id": o["order_id"] if mentions_order else ""})
    return cases, labels


b1_cases, b1_labels = make_cases(b1_orders, b1_lines, 400, batch1_start, datetime(2026, 9, 15, 23, 0))
all_orders_b2 = b1_orders + [o for o in b2_orders if o["order_id"] not in {x["order_id"] for x in b1_orders}]
b2_cases, b2_labels = make_cases(all_orders_b2, b1_lines + b2_lines, 100,
                                 datetime(2026, 9, 16), datetime(2026, 9, 30, 23, 0))


# ---------------------------------------------------------------- write files
H = {
    "customers": ["customer_id", "customer_name", "region", "country", "segment", "updated_at"],
    "products": ["product_id", "product_name", "product_family", "list_price_cents"],
    "orders": ["order_id", "customer_id", "order_date", "status", "currency", "updated_at"],
    "order_lines": ["order_line_id", "order_id", "product_id", "quantity", "unit_price_cents"],
    "order_events": ["event_id", "order_id", "event_type", "event_ts"],
    "case_labels": ["case_id", "true_issue_type", "true_order_id"],
}

for batch, data in {
    1: {"customers": customers, "products": products, "orders": b1_orders,
        "order_lines": b1_lines, "order_events": b1_events, "case_labels": b1_labels},
    2: {"customers": b2_customers, "orders": b2_orders,
        "order_lines": b2_lines, "order_events": b2_events, "case_labels": b2_labels},
}.items():
    for entity, rows in data.items():
        write_csv(OUT / f"batch_{batch}" / entity / f"{entity}_batch_{batch}.csv", rows, H[entity])

write_ndjson(OUT / "batch_1" / "support_cases" / "support_cases_batch_1.json", b1_cases)
write_ndjson(OUT / "batch_2" / "support_cases" / "support_cases_batch_2.json", b2_cases)

print("Generated:")
for p in sorted(OUT.rglob("*.*")):
    with open(p, encoding="utf-8") as f:
        n = sum(1 for _ in f) - (0 if p.suffix == ".json" else 1)
    print(f"  {p.relative_to(OUT)}  ({n} rows)")
print(f"\nBatch 2 includes {len(late_ids)} late-arriving orders and 150 status updates to batch-1 orders.")
