using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 플레이어가 다가가서 E를 눌러 조사할 수 있는 모든 것의 부모 클래스.
    /// Collider2D(Is Trigger 권장)를 같이 붙인다.
    /// </summary>
    public abstract class Interactable : MonoBehaviour
    {
        public virtual bool CanInteract => true;

        public abstract void Interact(PlayerInteractor player);
    }
}
