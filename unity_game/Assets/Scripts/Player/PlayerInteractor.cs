using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 가까운 물건/사람을 찾아 E 또는 Space로 상호작용한다.
    /// </summary>
    public class PlayerInteractor : MonoBehaviour
    {
        public float radius = 0.8f;

        [Tooltip("상호작용 가능할 때 머리 위에 띄울 표시 (예: '!' 말풍선)")]
        public GameObject promptIcon;

        Interactable current;

        void Update()
        {
            bool locked = (GameManager.Instance != null && GameManager.Instance.IsInputLocked)
                || (DialogueUI.Instance != null && DialogueUI.Instance.JustClosed);
            current = locked ? null : FindNearest();

            if (promptIcon != null) promptIcon.SetActive(current != null);

            if (current != null && (Input.GetKeyDown(KeyCode.E) || Input.GetKeyDown(KeyCode.Space)))
                current.Interact(this);
        }

        Interactable FindNearest()
        {
            Interactable nearest = null;
            float best = float.MaxValue;
            foreach (var hit in Physics2D.OverlapCircleAll(transform.position, radius))
            {
                var target = hit.GetComponentInParent<Interactable>();
                if (target == null || !target.CanInteract) continue;
                float dist = ((Vector2)hit.transform.position - (Vector2)transform.position).sqrMagnitude;
                if (dist < best)
                {
                    best = dist;
                    nearest = target;
                }
            }
            return nearest;
        }

        void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.yellow;
            Gizmos.DrawWireSphere(transform.position, radius);
        }
    }
}
