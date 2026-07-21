import { useMeta, buy } from '../meta/store';
import { META_UNLOCKS } from '../meta/catalog';
import { Icon } from './Icon';

/** Meta shop: spend banked currency on permanent, stackable unlocks. */
export function Shop() {
  const meta = useMeta();
  return (
    <div className="shop">
      <div className="shop-currency"><Icon name="droplet" /> {meta.currency}</div>
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
              <span className="shop-icon"><Icon name={u.icon} /></span>
              <span className="shop-name">{u.name}</span>
              <span className="shop-desc">{u.desc}</span>
              <span className="shop-cost"><Icon name="droplet" /> {u.cost}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
