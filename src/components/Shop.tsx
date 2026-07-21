import { useMeta, buy } from '../meta/store';
import { META_UNLOCKS } from '../meta/catalog';

/** Meta shop: spend banked currency on permanent, stackable unlocks. */
export function Shop() {
  const meta = useMeta();
  return (
    <div className="shop">
      <div className="shop-currency">🫧 {meta.currency}</div>
      <div className="shop-items">
        {META_UNLOCKS.map((u) => {
          const affordable = meta.currency >= u.cost;
          return (
            <button
              key={u.id}
              className="shop-item"
              disabled={!affordable}
              onClick={() => buy(u.id)}
            >
              <span className="shop-icon">{u.icon}</span>
              <span className="shop-name">{u.name}</span>
              <span className="shop-desc">{u.desc}</span>
              <span className="shop-cost">🫧 {u.cost}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
