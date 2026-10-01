using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 마지막 장(임진강 가, 지금의 임진각)의 엄마. 핵심 단서를 충분히 모았으면 재회 엔딩, 아니면 스쳐 지나간다.
    /// </summary>
    public class ReunionTrigger : Interactable
    {
        [Tooltip("재회에 필요한 핵심 단서 개수")]
        public int requiredKeyClues = 4;

        public DialogueData reunionDialogue;

        [TextArea(2, 4)]
        public string notEnoughMessage = "사람들 사이로 낯익은 뒷모습이 보였다... 하지만 확신이 서지 않는다. 단서를 더 찾아보자.";

        [Tooltip("재회 후 이동할 엔딩 장면")]
        public string endingScene = "Ending";

        public override void Interact(PlayerInteractor player)
        {
            var gm = GameManager.Instance;
            if (gm.KeyClueCount() < requiredKeyClues)
            {
                DialogueUI.Instance.Show(new[] { new DialogueLine { speaker = "나", text = notEnoughMessage } });
                return;
            }

            DialogueUI.Instance.Show(reunionDialogue != null ? reunionDialogue.lines : null, () =>
            {
                if (!string.IsNullOrEmpty(endingScene)) gm.LoadScene(endingScene);
            });
        }
    }
}
