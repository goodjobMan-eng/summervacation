using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Refugee1950
{
    /// <summary>
    /// 게임 전체 상태(모은 단서, 저장/불러오기)를 관리한다.
    /// 첫 장면에 하나만 두면 장면이 바뀌어도 유지된다.
    /// </summary>
    public class GameManager : MonoBehaviour
    {
        public static GameManager Instance { get; private set; }

        const string SaveKey = "refugee1950_save";

        [Tooltip("게임에 등장하는 모든 단서 (단서 수첩과 ID 조회에 사용)")]
        public List<ClueData> allClues = new List<ClueData>();

        readonly HashSet<string> collected = new HashSet<string>();
        readonly List<string> collectedOrder = new List<string>();

        /// <summary>대화 중이거나 수첩을 보는 중이면 플레이어가 움직이지 않는다.</summary>
        public bool IsInputLocked { get; set; }

        public event Action<ClueData> ClueCollected;

        public IReadOnlyList<string> CollectedIds => collectedOrder;

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        public bool HasClue(string clueId) => !string.IsNullOrEmpty(clueId) && collected.Contains(clueId);

        public bool HasAllClues(IEnumerable<ClueData> clues)
        {
            if (clues == null) return true;
            foreach (var clue in clues)
                if (clue != null && !HasClue(clue.id)) return false;
            return true;
        }

        public void AddClue(ClueData clue)
        {
            if (clue == null || !collected.Add(clue.id)) return;
            collectedOrder.Add(clue.id);
            ClueCollected?.Invoke(clue);
            Save();
        }

        public ClueData FindClue(string clueId) => allClues.Find(c => c != null && c.id == clueId);

        public int KeyClueCount()
        {
            int count = 0;
            foreach (var clue in allClues)
                if (clue != null && clue.isKeyClue && HasClue(clue.id)) count++;
            return count;
        }

        public void LoadScene(string sceneName)
        {
            IsInputLocked = false;
            SceneManager.LoadScene(sceneName);
            Save(sceneName);
        }

        [Serializable]
        class SaveData
        {
            public string scene;
            public List<string> clues = new List<string>();
        }

        public void Save(string sceneName = null)
        {
            var data = new SaveData
            {
                scene = sceneName ?? SceneManager.GetActiveScene().name,
                clues = new List<string>(collectedOrder),
            };
            PlayerPrefs.SetString(SaveKey, JsonUtility.ToJson(data));
            PlayerPrefs.Save();
        }

        public bool HasSave() => PlayerPrefs.HasKey(SaveKey);

        /// <summary>저장된 단서를 복원하고 저장된 장면으로 이동한다.</summary>
        public void Continue()
        {
            if (!HasSave()) return;
            var data = JsonUtility.FromJson<SaveData>(PlayerPrefs.GetString(SaveKey));
            collected.Clear();
            collectedOrder.Clear();
            foreach (var id in data.clues)
                if (collected.Add(id)) collectedOrder.Add(id);
            LoadScene(data.scene);
        }

        public void NewGame(string firstScene)
        {
            PlayerPrefs.DeleteKey(SaveKey);
            collected.Clear();
            collectedOrder.Clear();
            LoadScene(firstScene);
        }
    }
}
