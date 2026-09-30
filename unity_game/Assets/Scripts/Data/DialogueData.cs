using System;
using UnityEngine;

namespace Refugee1950
{
    [Serializable]
    public class DialogueLine
    {
        public string speaker;

        [TextArea(2, 6)]
        public string text;
    }

    /// <summary>
    /// 대화 한 묶음. Create → 피난길 → 대화 로 만든다.
    /// </summary>
    [CreateAssetMenu(fileName = "Dialogue_", menuName = "피난길/대화", order = 1)]
    public class DialogueData : ScriptableObject
    {
        public DialogueLine[] lines;
    }
}
