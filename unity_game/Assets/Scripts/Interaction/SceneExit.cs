using System.Collections.Generic;
using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 다음 장(장면)으로 넘어가는 출구. 필요한 단서를 다 모아야 지나갈 수 있다.
    /// Collider2D를 Is Trigger로 두면 밟았을 때, 아니면 E를 눌렀을 때 작동한다.
    /// </summary>
    public class SceneExit : Interactable
    {
        [Tooltip("Build Settings(Build Profiles)에 등록된 다음 장면 이름")]
        public string nextScene;

        public List<ClueData> requiredClues = new List<ClueData>();

        [Tooltip("단서가 부족할 때 주인공의 혼잣말")]
        [TextArea(2, 4)]
        public string lockedMessage = "아직 떠날 수 없어... 엄마가 어디로 갔는지 더 알아봐야 해.";

        [Tooltip("떠나기 전에 나오는 대화 (선택)")]
        public DialogueData leavingDialogue;

        public override void Interact(PlayerInteractor player)
        {
            if (!GameManager.Instance.HasAllClues(requiredClues))
            {
                DialogueUI.Instance.Show(new[] { new DialogueLine { speaker = "나", text = lockedMessage } });
                return;
            }

            if (leavingDialogue != null)
                DialogueUI.Instance.Show(leavingDialogue.lines, () => GameManager.Instance.LoadScene(nextScene));
            else
                GameManager.Instance.LoadScene(nextScene);
        }

        void OnTriggerEnter2D(Collider2D other)
        {
            if (GameManager.Instance.IsInputLocked) return;
            var player = other.GetComponent<PlayerInteractor>();
            if (player != null) Interact(player);
        }
    }
}
