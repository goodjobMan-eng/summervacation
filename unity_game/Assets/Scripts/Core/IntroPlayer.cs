using UnityEngine;

namespace Refugee1950
{
    /// <summary>
    /// 장면이 시작될 때 한 번 대화를 보여준다 (각 장의 도입부용).
    /// </summary>
    public class IntroPlayer : MonoBehaviour
    {
        public DialogueData intro;

        void Start()
        {
            if (intro != null) DialogueUI.Instance.Show(intro.lines);
        }
    }
}
